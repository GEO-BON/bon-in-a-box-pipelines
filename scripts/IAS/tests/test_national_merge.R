# Run from the repository root: Rscript scripts/IAS/tests/test_national_merge.R
script <- normalizePath('scripts/IAS/merge_datasets.R')
root <- tempfile('national-merge-tests-'); dir.create(root)
write_input <- function(dat, name) {
  path <- file.path(root, paste0(name, '.csv'))
  write.csv(dat, path, row.names = FALSE, na = '')
  path
}
records <- function(names, ids, years, source) {
  data.frame(location='Canada', locationID='CAN', ISO3='CAN', taxon=names,
    scientificName=names, taxonID=ids, eventDate=years, establishmentMeans='introduced',
    Kingdom_user='Plantae', linkID=paste0(source, seq_along(ids)), stringsAsFactors=FALSE)
}
griis <- records(c('Species A','External only'),c('1','9'),c(NA,1900),'G')
first <- records(c('Different reviewed label','Species B','External only'),c('1','2','9'),c(1900,1950,1901),'F')
national <- records(c('Species A','Species B','National only','Undated'),c('1','2','3','4'),c(1920,NA,1980,NA),'N')
national$sourceRow <- 1:4
national$uploadedTaxon <- c(' Original A ','Original B','Original C','Original D')
national$uploadedEventDate <- c(' 1920 ','','1980','')
taxa <- data.frame(taxonID=c('1','2','3','4','9'),kingdom='Plantae',phylum='P',class='C',order='O',family='F')
summary <- data.frame(dataset=c('GRIIS','FirstRecords'),input_records=c(2,3),clean_records=c(2,3),unresolved_terms=0,unresolved_locations=0,unresolved_taxa=0,excluded_from_merge=0)
args <- list(country_name=list(country=list(englishName='Canada',ISO3='CAN_1')),
  griis_clean=write_input(griis,'griis'),first_records_clean=write_input(first,'first'),
  full_taxa_list=write_input(taxa,'taxa'),cleaning_summary=write_input(summary,'summary'),
  qc_status=write_input(data.frame(check='overall',status='PASS'),'qc'),
  unmatched_values=write_input(data.frame(dataset=character(),field=character()),'unmatched'))
run <- function(national_input=NULL, script_path=script) {
  e <- new.env(); e$outputFolder <- tempfile(tmpdir=root); dir.create(e$outputFolder)
  inputs <- args; inputs$national_clean <- national_input
  e$biab_inputs <- function() inputs
  out <- list(); e$biab_output <- function(key,path) out[[key]] <<- read.csv(path,stringsAsFactors=FALSE)
  sys.source(script_path,e)
  out
}
base <- run()
stopifnot(identical(base,run('')),identical(base,run(NA_character_)))
# Optional argument: compare all five outputs to a pre-change script.
argv <- commandArgs(trailingOnly=TRUE)
if(length(argv)) stopifnot(isTRUE(all.equal(base,run(script_path=normalizePath(argv[1])),check.attributes=FALSE)))
out <- run(write_input(national,'national'))
x <- out$merged_dataset
stopifnot(nrow(x)==4L,all(x$inNationalChecklist),!any(x$taxon=='External only'))
a <- x[x$taxonID=='1',]; b <- x[x$taxonID=='2',]; c <- x[x$taxonID=='3',]; d <- x[x$taxonID=='4',]
stopifnot(a$eventDate==1920,a$nationalFirstRecordYear==1920,a$externalFirstRecordYear==1900,
 a$firstRecordSource=='NationalChecklist',grepl('FirstRecords: 1900',a$firstRecordEvidence),
 b$eventDate==1950,b$firstRecordSource=='FirstRecords',c$eventDate==1980,is.na(d$eventDate),
 a$uploadedTaxon==' Original A ',all(!c('isInvasiveInCountry','isInvasiveAnywhere') %in% names(x)),
 any(out$merge_conflicts$column=='eventDate'),tail(out$run_summary$QC_status,1)=='WARNING',
 tail(out$run_summary$input_records,1)==9,
 tail(out$merge_summary$external_records_not_selected,1)==2)
# Duplicate national dates: earliest national year still takes precedence.
duplicate <- rbind(national,national[1,]); duplicate$eventDate[5] <- 1910
x <- run(write_input(duplicate,'duplicate'))$merged_dataset
stopifnot(x$eventDate[x$taxonID=='1']==1910,nrow(x)==4)
# Names-only upload gets external years, retaining unmatched and undated taxa.
names_only <- national; names_only$eventDate <- NA
x <- run(write_input(names_only,'names-only'))$merged_dataset
stopifnot(x$eventDate[x$taxonID=='1']==1900,is.na(x$eventDate[x$taxonID=='3']))
# Wrong-country and empty uploads must not silently switch to default mode.
wrong <- national; wrong$ISO3 <- 'AUS'
for (dat in list(wrong,national[FALSE,])) {
  err <- tryCatch({run(write_input(dat,'invalid'));NULL},error=conditionMessage)
  stopifnot(!is.null(err))
}
# Exact-name fallback when both records lack IDs; never match different locations.
old_args <- args
fallback_national <- national[1:2,]
fallback_national$taxonID <- NA
fallback_national$eventDate <- NA
fallback_first <- first
fallback_first$taxon <- fallback_first$scientificName <- c('Species A','Species B','External only')
fallback_first$taxonID <- NA
fallback_first$locationID[2] <- 'OTHER_LOCATION'
args$first_records_clean <- write_input(fallback_first,'fallback-first')
x <- run(write_input(fallback_national,'fallback-national'))$merged_dataset
stopifnot(nrow(x)==2,x$eventDate[x$taxon=='Species A']==1900,
          is.na(x$eventDate[x$taxon=='Species B']))
args <- old_args
# Preserve explicit invasive evidence and flag contradictory statuses.
flagged <- national; flagged$isInvasiveInCountry <- FALSE
external_flagged <- griis; external_flagged$isInvasiveInCountry <- TRUE
args$griis_clean <- write_input(external_flagged,'flagged-griis')
x <- run(write_input(flagged,'flagged-national'))
stopifnot(any(x$merge_conflicts$column=='isInvasiveInCountry'))
args <- old_args
# A valid checklist can be entirely unmatched to reviewed taxonomy.
unknown <- national[1,]; unknown$taxonID <- NA
args$full_taxa_list <- write_input(taxa[FALSE,],'empty-taxonomy')
x <- run(write_input(unknown,'unknown-national'))$merged_dataset
stopifnot(nrow(x)==1,x$taxon=='Species A')
args <- old_args
cat('PASS: no-upload regression; national membership, dates, provenance, conflicts, summaries, and invalid inputs.\n')
