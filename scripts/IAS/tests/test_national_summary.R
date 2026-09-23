# Run from the repository root: Rscript scripts/IAS/tests/test_national_summary.R
script <- normalizePath('scripts/IAS/summarise_ias.R')
root <- tempfile('national-summary-tests-'); dir.create(root)
run <- function(dat, script_path=script) {
  folder <- tempfile(tmpdir=root); dir.create(folder)
  merged <- file.path(folder,'merged.csv'); write.csv(dat,merged,row.names=FALSE,na='')
  gbif <- file.path(folder,'gbif.csv')
  write.csv(data.frame(year=c(1900,1970,1970,2000),recordscount=c(2,3,4,5)),gbif,row.names=FALSE)
  e <- new.env(); e$outputFolder <- folder
  e$biab_inputs <- function() list(merged_dataset=merged,gbif_country_observations=gbif)
  e$biab_error_stop <- function(...) stop(...)
  out <- list(); e$biab_output <- function(key,path) {
    out[[key]] <<- if(grepl('html$',path)) paste(readLines(path,warn=FALSE),collapse='\n') else read.csv(path,stringsAsFactors=FALSE)
  }
  suppressPackageStartupMessages(sys.source(script_path,e))
  out
}
legacy <- data.frame(taxon=c('A','B','C','D'),kingdom=c('Plantae','Animalia','Plantae','Animalia'),
 location='Canada',origDB=c('GRIIS; FirstRecords','GRIIS','FirstRecords','GRIIS'),
 isInvasiveAnywhere=c('TRUE','FALSE; TRUE','TRUE','FALSE'),eventDate=c(1900,1970,2000,2000))
x <- run(legacy)
argv <- commandArgs(trailingOnly=TRUE)
if(length(argv)) {
 old <- run(legacy,normalizePath(argv[1]))
 stopifnot(identical(x$ias_summary,old$ias_summary),identical(x$ias_annual_summary,old$ias_annual_summary))
}
# No invasive flags or GRIIS provenance are needed in national mode.
national <- legacy[,c('taxon','kingdom','location','eventDate')]
national$eventDate <- c(1900,1970,NA,2000)
national$inNationalChecklist <- c(TRUE,TRUE,TRUE,FALSE)
x <- run(national)
stopifnot('nationalChecklist' %in% names(x$ias_summary),
 x$ias_summary$nationalChecklist[x$ias_summary$Variable=='National checklist species']=='3 (100%)',
 x$ias_summary$nationalChecklist[x$ias_summary$Variable=='All Species']=='2 (66.67%)',
 sum(x$ias_annual_summary$firstRecordCount)==2,
 x$ias_annual_summary$gbifRecordsCount[x$ias_annual_summary$year==1970]==7,
 grepl('National checklist species',x$ias_summary_table,fixed=TRUE),
 !grepl('Number of IAS',x$ias_summary_table,fixed=TRUE))
# With no dates, all checklist members remain in totals and annual counts are zero.
national$eventDate <- NA
x <- run(national)
stopifnot(sum(x$ias_annual_summary$firstRecordCount)==0,
 x$ias_summary$nationalChecklist[x$ias_summary$Variable=='All Species']=='0 (0%)')
# No selected members must not fall back to external/GRIIS records.
national$inNationalChecklist <- FALSE
x <- run(national)
stopifnot(sum(x$ias_annual_summary$firstRecordCount)==0,
 x$ias_summary$nationalChecklist[x$ias_summary$Variable=='National checklist species']=='0 (NA%)')
national$inNationalChecklist <- 'invalid'
err <- tryCatch({run(national);NULL},error=conditionMessage)
stopifnot(grepl('inNationalChecklist must contain',err,fixed=TRUE))
cat('PASS: legacy regression, national-only membership, missing dates/status, annual counts, empty selection, validation and HTML rendering.\n')
