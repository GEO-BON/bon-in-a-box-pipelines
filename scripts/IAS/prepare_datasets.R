####### SInAS workflow: Integration and standardisation of alien species data ###########
##
## Step 1: Prepare databases of alien taxon distribution and first records
## as input datasets to create a merged database
## 
## Hanno Seebens, Giessen, 02.07.2025
#########################################################################################
library(rgbif) # for checking names, records and taxonomy; note: usage of rgbif may cause warnings like "Unknown or uninitalised column: " which is a bug. Can be ignored.
library(data.table)
#library(tidyverse)
library(tidyr)
library(stringr)
library(stringi)
library(dplyr)
library(openxlsx)


input <- biab_inputs()
country_name <- input$country_name$country$englishName

iso3 <- input$country_name$country$ISO3
print(iso3)
# Loading in datasets
griis <- read.csv(input$griis_checklist)
firstrecords <- read.csv(input$first_records)
#griis <- read.csv("C:/Users/Samara/Desktop/bon-in-a-box-pipelines/output/IAS/P1_ChecklistDownload/download_checklist/24WCclDWWTOfF_TezBFTZE32-OPe/GRIIS_checklist.csv")
#firstrecords <- read.csv("C:/Users/Samara/Desktop/bon-in-a-box-pipelines/output/IAS/P2_FirstRecordsData/standardise_data/MvoeUdjrbO9xW2gLxy9qcQhDgtHB/FirstRecords_cleaned.csv")

# Loading in config files

# Specifying in filters
Dataset_brief_name <- input$dataset
Taxon_group <- input$taxon_group
Column_recordID <- input$column_recordid
Column_taxon <- input$column_taxon
Column_author <- input$column_author
Column_scientificName <- input$column_scientificname
Column_location <- input$column_location
Column_kingdom <- input$column_kingdom
Column_country_ISO <- input$column_country_iso
Column_eventDate1 <- input$column_eventdate1
Column_eventDate2 <- input$column_eventdate2
Column_establishmentMeans <- input$column_establishmentmeans
Column_occurrenceStatus <- input$column_occurrencestatus
Column_degreeOfEstablishment <- input$column_degreeofestablishment
Column_pathway <- input$column_pathway
Column_habitat <- input$column_habitat
Column_bibliographicCitation <- input$column_bibliographiccitation
Column_additional <- input$column_additional

# Filter GRIIS data set 
GRIIS <- griis %>% 
  dplyr::filter(countryInCompendium == TRUE) %>% 
  dplyr::filter(checklistType == "national") %>% 
  dplyr::filter(checklistLevel != "Secondary") %>% 
  dplyr::filter(kingdom %in% c("PLANTAE","ANIMALIA")) %>% 
  dplyr::filter(habitat %in% c("TERRESTRIAL","FRESHWATER","FRESHWATER|BRACKISH",
                               "TERRESTRIAL|FRESHWATER", "MARINE|FRESHWATER|BRACKISH",
                               "TERRESTRIAL|BRACKISH", "TERRESTRIAL|FRESHWATER|BRACKISH",
                               "TERRESTRIAL|MARINE|FRESHWATER", "TERRESTRIAL|MARINE|BRACKISH",
                               "MARINE|FRESHWATER", "TERRESTRIAL|MARINE")) 

# Filter First Records data set 
FirstRecords <- firstrecords %>% 
  dplyr::filter(kingdom %in% c("PLANTAE","ANIMALIA")) %>% 
  dplyr::filter(habitat %in% c("TERRESTRIAL","FRESHWATER","FRESHWATER|BRACKISH",
                               "TERRESTRIAL|FRESHWATER", "MARINE|FRESHWATER|BRACKISH",
                               "TERRESTRIAL|BRACKISH", "TERRESTRIAL|FRESHWATER|BRACKISH",
                               "TERRESTRIAL|MARINE|FRESHWATER", "TERRESTRIAL|MARINE|BRACKISH",
                               "MARINE|FRESHWATER", "TERRESTRIAL|MARINE"))

print("************")
#######################
## Step 1: Prepare datasets
#######################

# removing duplicates from a given country

 if (any(duplicated(FirstRecords$taxonID))) {
    
    ## remove duplicate records for single species within country for First Records database - keep earliest eventDate 
    FirstRecords_COUNTRY <- FirstRecords %>% mutate(original_order = row_number())
    
    FirstRecords_COUNTRY_multi <- FirstRecords_COUNTRY %>% 
      dplyr::group_by(taxonID) %>%
      dplyr::filter(dplyr::n() > 1) %>%
      dplyr::group_modify(~ {
        non_na_rows <- dplyr::filter(.x, !is.na(eventDate))
        if (nrow(non_na_rows) > 1) {
          # Keep row with earliest eventDate
          dplyr::slice_min(non_na_rows, order_by = eventDate, n = 1, with_ties = FALSE)
        } else if (nrow(non_na_rows) == 1) {
          # Only one row with date
          non_na_rows
        } else {
          # All eventDate are NA — keep first row of original group
          dplyr::slice_head(.x, n = 1)
        }
      }) %>%
      dplyr::ungroup()
    
    FirstRecords_COUNTRY_single <- FirstRecords_COUNTRY %>%
      dplyr::group_by(taxonID) %>%
      dplyr::filter(dplyr::n() == 1) %>%
      dplyr::ungroup()
    
    FirstRecords_COUNTRY <- dplyr::bind_rows(FirstRecords_COUNTRY_multi, FirstRecords_COUNTRY_single) %>%
      dplyr::arrange(original_order) %>%
      dplyr::select(-original_order) %>%
      dplyr::relocate(taxonID, .before = eventDate)
    
  } else {FirstRecords_COUNTRY <- FirstRecords}



## creating a list of input datasets
datasets_in <- list(
  GRIIS = GRIIS,
  FirstRecords = FirstRecords_COUNTRY
)

## creating FileInfo data frame to store information about datasets and their columns
dataset_names <- names(datasets_in)
  if (is.null(dataset_names)) dataset_names <- rep("", length(datasets_in))

  default_dataset_name <- if (exists("Dataset_brief_name")) as.character(Dataset_brief_name) else ""
  if (length(default_dataset_name) == 0) default_dataset_name <- ""

  for (j in seq_along(dataset_names)) {
    if (is.na(dataset_names[[j]]) || dataset_names[[j]] == "") {
      dataset_names[[j]] <- if (length(default_dataset_name) >= j && !is.na(default_dataset_name[[j]]) && default_dataset_name[[j]] != "") {
        default_dataset_name[[j]]
      } else if (length(default_dataset_name) == 1 && !is.na(default_dataset_name) && default_dataset_name != "") {
        default_dataset_name
      } else {
        paste0("Dataset", j)
      }
    }
  }

  get_mapping <- function(x, idx) {
    if (is.null(x)) return(NA_character_)
    x <- as.character(x)
    if (length(x) == 0) return(NA_character_)
    val <- if (length(x) >= idx) x[[idx]] else x[[1]]
    if (is.na(val) || trimws(val) == "") return(NA_character_)
    val
  }

  FileInfo <- data.frame(
    Dataset_brief_name = dataset_names,
    Taxon_group = rep(get_mapping(Taxon_group, 1), length(datasets_in)),
    Column_recordID = sapply(seq_along(datasets_in), function(j) get_mapping(Column_recordID, j)),
    Column_taxon = sapply(seq_along(datasets_in), function(j) get_mapping(Column_taxon, j)),
    Column_author = sapply(seq_along(datasets_in), function(j) get_mapping(Column_author, j)),
    Column_scientificName = sapply(seq_along(datasets_in), function(j) get_mapping(Column_scientificName, j)),
    Column_location = sapply(seq_along(datasets_in), function(j) get_mapping(Column_location, j)),
    Column_kingdom = sapply(seq_along(datasets_in), function(j) get_mapping(Column_kingdom, j)),
    Column_country_ISO = sapply(seq_along(datasets_in), function(j) get_mapping(Column_country_ISO, j)),
    Column_eventDate1 = sapply(seq_along(datasets_in), function(j) get_mapping(Column_eventDate1, j)),
    Column_eventDate2 = sapply(seq_along(datasets_in), function(j) get_mapping(Column_eventDate2, j)),
    Column_establishmentMeans = sapply(seq_along(datasets_in), function(j) get_mapping(Column_establishmentMeans, j)),
    Column_occurrenceStatus = sapply(seq_along(datasets_in), function(j) get_mapping(Column_occurrenceStatus, j)),
    Column_degreeOfEstablishment = sapply(seq_along(datasets_in), function(j) get_mapping(Column_degreeOfEstablishment, j)),
    Column_pathway = sapply(seq_along(datasets_in), function(j) get_mapping(Column_pathway, j)),
    Column_habitat = sapply(seq_along(datasets_in), function(j) get_mapping(Column_habitat, j)),
    Column_bibliographicCitation = sapply(seq_along(datasets_in), function(j) get_mapping(Column_bibliographicCitation, j)),
    Column_additional = sapply(seq_along(datasets_in), function(j) get_mapping(Column_additional, j)),
    stringsAsFactors = FALSE
  )

  if (nrow(FileInfo) != length(datasets_in)) {
    stop("Mismatch between number of datasets and number of FileInfo rows.")
  }

PrepareDatasets <- function(FileInfo=NULL){

  if (is.null(datasets_in)) {
    if (!exists("datasets", inherits = TRUE)) {
      stop("No datasets found. Provide 'datasets_in' or define a non-empty global 'datasets' list.")
    }
    datasets_in <- get("datasets", inherits = TRUE)
    if (length(datasets_in) == 0) {
      stop("No datasets found. Provide 'datasets_in' or define a non-empty global 'datasets' list.")
    }
  }

    results <- list()
  for (i in seq_along(datasets_in)){#
    
    ## load data set
    dat <- datasets_in[[i]]
  
    ## correct modification of import of column names through R
    col_names_import <- colnames(dat)
  
    ## check and rename required column names
    all_column_names <- vector()
    
    if (!is.na(FileInfo[i,"Column_recordID"]) & FileInfo[i,"Column_recordID"]!=""){
      col_recordID <- FileInfo[i,"Column_recordID"]
      colnames(dat)[col_names_import==col_recordID] <- paste("recordID",FileInfo[i,"Dataset_brief_name"],sep="_")
      all_column_names <- c(all_column_names,paste("recordID",FileInfo[i,"Dataset_brief_name"],sep="_"))
    }
    
    if (!is.na(FileInfo[i,"Column_taxon"]) & FileInfo[i,"Column_taxon"]!=""){
      col_spec_names <- FileInfo[i,"Column_taxon"]
      all_column_names <- col_spec_names
      if (is.na(col_spec_names)) stop(paste("Column with taxon names not found in",FileInfo[i,"Dataset_brief_name"],"file!"))
      if (!is.na(FileInfo[i,"Column_author"]) & FileInfo[i,"Column_author"]!=""){
        col_author <- FileInfo[i,"Column_author"]
        # all_column_names <- c(all_column_names,"Author")
        dat[,col_spec_names] <- paste(dat[,col_spec_names],dat[,col_author]) # add author to taxon name
        dat[,col_spec_names] <- gsub(" NA","",dat[,col_spec_names]) # remove missing author names
      }
    }
    
    if (!is.na(FileInfo[i,"Column_scientificName"]) & FileInfo[i,"Column_scientificName"]!=""){
      col_spec_names <- FileInfo[i,"Column_scientificName"]
      if (is.na(col_spec_names)) stop(paste("Column with taxon names not found in",FileInfo[i,"Dataset_brief_name"],"file!"))
      all_column_names <- col_spec_names
    }

    col_reg_names <- FileInfo[i,"Column_location"]
    if (is.na(col_reg_names)) stop(paste("Column with location names not found in",FileInfo[i,"Dataset_brief_name"],"file!"))
    all_column_names <- c(all_column_names,col_reg_names)

    ## check and rename optional column names
    if (!is.na(FileInfo[i,"Column_kingdom"]) & FileInfo[i,"Column_kingdom"]!=""){
      col_kingdom <- FileInfo[i,"Column_kingdom"]
      all_column_names <- c(all_column_names,col_kingdom)
    }
    # if (!is.na(FileInfo[i,"Column_island_name"]) & FileInfo[i,"Column_island_name"]!=""){
    #   col_islandname <- FileInfo[i,"Column_island_name"]
    #   ind_NA <- is.na(dat$island)
    #   dat$location_orig[!ind_NA] <- dat$island[!ind_NA] # replace country names by island names
    # }
    if (!is.na(FileInfo[i,"Column_country_ISO"]) & FileInfo[i,"Column_country_ISO"]!=""){
      col_country_code <- FileInfo[i,"Column_country_ISO"]
      all_column_names <- c(all_column_names,col_country_code)
    }
    if (!is.na(FileInfo[i,"Column_eventDate1"]) & FileInfo[i,"Column_eventDate1"]!=""){
      col_eventDate_1 <- FileInfo[i,"Column_eventDate1"]
      all_column_names <- c(all_column_names,col_eventDate_1)
    }
    if (!is.na(FileInfo[i,"Column_eventDate2"]) & FileInfo[i,"Column_eventDate2"]!=""){
      col_eventDate_2 <- FileInfo[i,"Column_eventDate2"]
      all_column_names <- c(all_column_names,col_eventDate_2)
    }
    if (!is.na(FileInfo[i,"Column_establishmentMeans"]) & FileInfo[i,"Column_establishmentMeans"]!=""){
      col_establishmentMeans <- FileInfo[i,"Column_establishmentMeans"]
      colnames(dat)[col_names_import==col_establishmentMeans] <- "establishmentMeans"
      all_column_names <- c(all_column_names,"establishmentMeans")
      dat$establishmentMeans <- tolower(dat$establishmentMeans)
    }
    if (!is.na(FileInfo[i,"Column_occurrenceStatus"]) & FileInfo[i,"Column_occurrenceStatus"]!=""){
      col_occurrenceStatus <- FileInfo[i,"Column_occurrenceStatus"]
      if (col_establishmentMeans==col_occurrenceStatus){ # check if same column has been assigned before in establishmentMeans
        dat$occurrenceStatus <- dat$establishmentMeans # if yes, duplicate column
      } else {
        colnames(dat)[col_names_import==col_occurrenceStatus] <- "occurrenceStatus"
      }
      all_column_names <- c(all_column_names,"occurrenceStatus")
      dat$occurrenceStatus <- tolower(dat$occurrenceStatus)
    }
    if (!is.na(FileInfo[i,"Column_degreeOfEstablishment"]) & FileInfo[i,"Column_degreeOfEstablishment"]!=""){
      col_degreeOfEstablishment <- FileInfo[i,"Column_degreeOfEstablishment"]
      if (col_establishmentMeans==col_degreeOfEstablishment){ # check if same column has been assigned before in establishmentMeans
        dat$degreeOfEstablishment <- dat$establishmentMeans # if yes, duplicate column
      } else if (col_establishmentMeans==col_occurrenceStatus){
        dat$degreeOfEstablishment <- dat$occurrenceStatus # if yes, duplicate column
      } else {
        colnames(dat)[col_names_import==col_degreeOfEstablishment] <- "degreeOfEstablishment"
      }
      all_column_names <- c(all_column_names,"degreeOfEstablishment")
      dat$degreeOfEstablishment <- tolower(dat$degreeOfEstablishment)
      }
    if (!is.na(FileInfo[i,"Column_pathway"]) & FileInfo[i,"Column_pathway"]!=""){
    col_pathway <- FileInfo[i,"Column_pathway"]
    all_column_names <- c(all_column_names,col_pathway)
    }
    if (!is.na(FileInfo[i,"Column_habitat"]) & FileInfo[i,"Column_habitat"]!=""){
      col_habitat <- FileInfo[i,"Column_habitat"]
      all_column_names <- c(all_column_names,col_habitat)
    }
    if (!is.na(FileInfo[i,"Column_bibliographicCitation"]) & FileInfo[i,"Column_bibliographicCitation"]!=""){
      col_bibliographicCitation <- FileInfo[i,"Column_bibliographicCitation"]
      all_column_names <- c(all_column_names,col_bibliographicCitation)
    }

    if (!is.na(FileInfo[i,"Column_additional"]) & FileInfo[i,"Column_additional"]!=""){
      col_additional <- FileInfo[i,"Column_additional"]
      addit_cols <- unlist(strsplit(col_additional, ";\\s*"))
      addit_cols <- trimws(addit_cols)
      addit_cols <- addit_cols[addit_cols != ""]
      matched_idx <- pmatch(addit_cols, colnames(dat))
      missing_addit <- addit_cols[is.na(matched_idx)]
      if (length(missing_addit) > 0) {
        warning(
          paste0(
            "Ignoring unmatched additional columns in ",
            FileInfo[i, "Dataset_brief_name"],
            ": ",
            paste(missing_addit, collapse = ", ")
          )
        )
      }
      all_column_names <- c(all_column_names, colnames(dat)[matched_idx[!is.na(matched_idx)]])
    }

    all_column_names <- unique(all_column_names)
    ## keep required, optional and additional columns
    dat_out <- dat[,all_column_names]
    
    # Only replace missing values in text columns; keep NA in numeric/date columns.
    for (col_name in colnames(dat_out)) {
      if (is.factor(dat_out[[col_name]])) {
        dat_out[[col_name]] <- as.character(dat_out[[col_name]])
      }
      if (is.character(dat_out[[col_name]])) {
        dat_out[[col_name]][is.na(dat_out[[col_name]])] <- ""
      }
    }
    
    ## standardise column names
    col_names_import <- colnames(dat_out)
    if (exists("col_spec_names")) colnames(dat_out)[col_names_import==col_spec_names] <- "taxon_orig"
    if (exists("col_reg_names")) colnames(dat_out)[col_names_import==col_reg_names] <- "location_orig"
    if (exists("col_kingdom")) colnames(dat_out)[col_names_import==col_kingdom] <- "Kingdom_user"
    if (exists("col_country_code")) colnames(dat_out)[col_names_import==col_country_code] <- "Country_ISO"
    if (exists("col_eventDate_1")) colnames(dat_out)[col_names_import==col_eventDate_1] <- "eventDate"
    if (exists("col_eventDate_2")) colnames(dat_out)[col_names_import==col_eventDate_2] <- "eventDate2"
    if (exists("col_habitat")) colnames(dat_out)[col_names_import==col_habitat] <- "habitat"
    if (exists("col_pathway")) colnames(dat_out)[col_names_import==col_pathway] <- "pathway"
    if (exists("col_bibliographicCitation")) colnames(dat_out)[col_names_import==col_bibliographicCitation] <- "bibliographicCitation"
    
    if (exists("col_habitat")) dat$habitat <- tolower(dat$habitat)

    options(warn=-1)
    rm(col_spec_names,col_reg_names,col_kingdom,col_country_code,col_eventDate_1,
       col_eventDate_2,col_establishmentMeans,col_occurrenceStatus,
       col_habitat,col_bibliographicCitation,col_establishmentMeans,col_occurrenceStatus,
       col_degreeOfEstablishment,col_pathway)
    options(warn=1)
    
    ## remove rows with missing taxon and region names
    dat_out <- dat_out[!dat_out$location_orig=="",]
    dat_out <- dat_out[!dat_out$taxon_orig=="",]
    
    dat_out$Taxon_group <- rep(FileInfo[i, "Taxon_group"], nrow(dat_out))
    
    colnames(dat_out) <- gsub("\\.+","_",colnames(dat_out))
    dat_out$taxon_orig <- gsub("\"","",dat_out$taxon_orig) # remove additional quotes to avoid difficulties with export
    dat_out$taxon_orig <- gsub("\\\\","",dat_out$taxon_orig) # remove backshlashes

    dat_out <- unique(dat_out) # remove duplicates
    
    results[[names(datasets_in)[i]]] <- dat_out
  }
  return(results)
}

results <- PrepareDatasets(FileInfo=FileInfo)
print(names(results))

StandardiseTerms <- function(FileInfo=NULL){

 inputfiles <- results
  
  ## translation tables
  translation_estabmeans <- read.xlsx("/scripts/IAS/Config/Translation_establishmentMeans.xlsx",sheet=1)
  translation_occurrence <- read.xlsx("/scripts/IAS/Config/Translation_occurrenceStatus.xlsx",sheet=1)
  translation_degrEstab <- read.xlsx("/scripts/IAS/Config/Translation_degreeOfEstablishment.xlsx",sheet=1)
  translation_pathway <- read.xlsx("/scripts/IAS/Config/Translation_pathway.xlsx",sheet=1)
  translation_habitat <- read.xlsx("/scripts/IAS/Config/Translation_habitat.xlsx",sheet=1)
  
  clean_datasets <- list()
  unresolved_terms <- list()
  
  for (i in seq_along(inputfiles)){
    
    dat <- inputfiles[[i]]
    dataset_name <- names(inputfiles)[i]

    unresolved_estabmeans <- vector()
    unresolved_occurrenceStatus <- vector()
    unresolved_degreeOfEstablishment <- vector()
    unresolved_pathway <- vector()
    unresolved_habitat <- vector()
    resolved_estabmeans <- vector()
    resolved_occurrenceStatus <- vector()
    resolved_degreeOfEstablishment <- vector()
    resolved_pathway <- vector()
    resolved_habitat <- vector()
    
    ## Darwin Core: establishmentMeans
    if (any(colnames(dat)=="establishmentMeans")){
      dat$establishmentMeans <- gsub("^\\s+|\\s+$", "",dat$establishmentMeans) # trim leading and trailing whitespace
      # identify matches of alternative terms...
      ind <- match(tolower(dat$establishmentMeans),tolower(translation_estabmeans$origTerm)) # identify matches
      unresolved_estabmeans <- unique(dat$establishmentMeans[is.na(ind)]) # store mis-matches
      resolved_estabmeans <- unique(dat$establishmentMeans[!is.na(ind)]) # store mis-matches
      translated <- translation_estabmeans$newTerm[ind]
      indNA <- is.na(translated)
      dat$establishmentMeans[!indNA] <- translated[!indNA]  # replace strings
      # identify matches of Darwin Core
      ind <- match(tolower(dat$establishmentMeans),tolower(translation_estabmeans$newTerm)) # identify matches with Darwin Core
      dat$establishmentMeans <- translation_estabmeans$newTerm[ind] # replace strings
      dat$establishmentMeans[is.na(ind)] <- "" # indicate mis-matches
    }

    ## Darwin Core: occurrenceStatus
    if (any(colnames(dat)=="occurrenceStatus")){
      dat$occurrenceStatus <- gsub("^\\s+|\\s+$", "",dat$occurrenceStatus) # trim leading and trailing whitespace
      # identify matches of alternative terms...
      ind <- match(tolower(dat$occurrenceStatus),tolower(translation_occurrence$origTerm)) # identify matches
      unresolved_occurrenceStatus <- unique(dat$occurrenceStatus[is.na(ind)]) # store mis-matches
      resolved_occurrenceStatus <- unique(dat$occurrenceStatus[!is.na(ind)]) # store mis-matches
      translated <- translation_occurrence$newTerm[ind]
      indNA <- is.na(translated)
      dat$occurrenceStatus[!indNA] <- translated[!indNA]  # replace strings
      # identify matches of Darwin Core
      dat$occurrenceStatus[dat$occurrenceStatus!="absent"] <- "present" # Assumption (!) that all species are present if not listed otherwise
    }
    
    ## Darwin Core: degreeOfEstablishment (not officially accepted by Darwin Core)
    if (any(colnames(dat)=="degreeOfEstablishment")){
      dat$degreeOfEstablishment <- gsub("^\\s+|\\s+$", "",dat$degreeOfEstablishment) # trim leading and trailing whitespace
      # identify matches of alternative terms...
      ind <- match(tolower(dat$degreeOfEstablishment),tolower(translation_degrEstab$origTerm)) # identify matches of translated terms
      unresolved_degreeOfEstablishment <- unique(dat$degreeOfEstablishment[is.na(ind)]) # store mis-matches
      resolved_degreeOfEstablishment <- unique(dat$degreeOfEstablishment[!is.na(ind)]) # store mis-matches
      translated <- translation_degrEstab$newTerm[ind]
      indNA <- is.na(translated)
      dat$degreeOfEstablishment[!indNA] <- translated[!indNA]  # replace strings
      # identify matches of Darwin Core
      ind <- match(tolower(dat$degreeOfEstablishment),tolower(translation_degrEstab$newTerm)) # identify matches with Darwin Core
      dat$degreeOfEstablishment <- translation_degrEstab$newTerm[ind] # replace strings
      dat$degreeOfEstablishment[is.na(ind)] <- "" # indicate mis-matches
    }
    
    ## Darwin Core: pathway
    if (any(colnames(dat)=="pathway")){
      dat$pathway <- gsub("^\\s+|\\s+$", "",dat$pathway) # trim leading and trailing whitespace
      # identify matches of alternative terms...
      ind <- match(tolower(dat$pathway),tolower(translation_pathway$origTerm)) # identify matches of translated terms
      unresolved_pathway <- unique(dat$pathway[is.na(ind)]) # store mis-matches
      resolved_pathway <- unique(dat$pathway[!is.na(ind)]) # store mis-matches
      translated <- translation_pathway$newTerm[ind]
      indNA <- is.na(translated)
      dat$pathway[!indNA] <- translated[!indNA]  # replace strings
      # identify matches of Darwin Core
      ind <- match(tolower(dat$pathway),tolower(translation_pathway$newTerm)) # identify matches with Darwin Core
      dat$pathway <- translation_pathway$newTerm[ind] # replace strings
      dat$pathway[is.na(ind)] <- "" # indicate mis-matches
    }
    
    ## Darwin Core: habitat
    if (any(colnames(dat)=="habitat")){
      dat$habitat <- gsub("^\\s+|\\s+$", "",dat$habitat) # trim leading and trailing whitespace
      # identify matches of alternative terms...
      ind <- match(tolower(dat$habitat),tolower(translation_habitat$origTerm)) # identify matches of translated terms
      unresolved_habitat <- unique(dat$habitat[is.na(ind)]) # store mis-matches
      resolved_habitat <- unique(dat$habitat[!is.na(ind)]) # store matches
      translated <- translation_habitat$newTerm[ind]
      indNA <- is.na(translated)
      dat$habitat[!indNA] <- translated[!indNA]  # replace strings
      # identify matches of Darwin Core
      ind <- match(tolower(dat$habitat),tolower(translation_habitat$newTerm)) # identify matches with Darwin Core
      dat$habitat <- translation_habitat$newTerm[ind] # replace strings
      dat$habitat[is.na(ind)] <- "" # indicate mis-matches
    }
    
    
    ## Output ###########################
    
    all_unresolved <- unique(c(unresolved_estabmeans, unresolved_occurrenceStatus,
                                unresolved_degreeOfEstablishment, unresolved_pathway))
    all_unresolved <- all_unresolved[!all_unresolved %in% resolved_estabmeans]
    all_unresolved <- all_unresolved[!all_unresolved %in% resolved_occurrenceStatus]
    all_unresolved <- all_unresolved[!all_unresolved %in% resolved_degreeOfEstablishment]
    all_unresolved <- all_unresolved[!all_unresolved %in% resolved_pathway]
    all_unresolved <- all_unresolved[!all_unresolved %in% resolved_habitat]
    
    clean_datasets[[dataset_name]] <- dat
    unresolved_terms[[dataset_name]] <- all_unresolved
  }
  
  return(list(clean_datasets = clean_datasets, unresolved_terms = unresolved_terms))
}

step2 <- StandardiseTerms(FileInfo = FileInfo)
print(head(step2$clean_datasets[["FirstRecords"]]))      # cleaned data for one dataset
print(head(step2$unresolved_terms[["FirstRecords"]]))    # unresolved terms vector for that dataset
print(head(step2$clean_datasets[["GRIIS"]]))      # cleaned data for one dataset
print(head(step2$unresolved_terms[["GRIIS"]])) 

StandardiseLocationNames <- function(FileInfo = NULL, step2_output = NULL){
  
  inputfiles <- step2_output$clean_datasets  # named list from StandardiseTerms()
  
  ## load location tables #################################################
  regions <- read.xlsx("/scripts/IAS/Config/AllLocations.xlsx", sheet = 2, na.strings = "")
  regions <- regions[, c("locationID", "location", "location_var")]
  regions$location_var <- tolower(regions$location_var)
  regions$location_lower <- tolower(regions$location)
  
  subregions <- read.xlsx("/scripts/IAS/Config/AllLocations.xlsx", sheet = 3, na.strings = "")
  subregions <- subregions[, c("locationID", "location", "location_var", "gadm1_name", "gadm1_var")]
  subregions$gadm1_var <- tolower(subregions$gadm1_var)
  subregions$gadm1_lower <- tolower(subregions$gadm1_name)
  
  dup <- unique(gsub("\\s*\\(.*?\\)", "", subregions$gadm1_name)[duplicated(gsub("\\s*\\(.*?\\)", "", subregions$gadm1_name))])
  
  clean_datasets <- list()
  missing_locations <- list()
  
  ## loop over all data sets ############################################
  for (i in seq_along(inputfiles)){
    
    dat <- inputfiles[[i]]
    dataset_name <- names(inputfiles)[i]
    
    dat_match1 <- dat
    dat_match1$order <- 1:nrow(dat_match1)
    dat_match1$location_orig <- gsub("\\xa0|\\xc2", " ", dat_match1$location_orig)
    dat_match1$location_orig <- gsub("^\\s+|\\s+$", "", dat_match1$location_orig)
    dat_match1$location_orig <- gsub("  ", " ", dat_match1$location_orig)
    dat_match1$location_orig <- gsub(" \\(the\\)", "", dat_match1$location_orig)
    dat_match1$location_lower <- tolower(dat_match1$location_orig)
    
    dat_match_regions <- merge(dat_match1, regions, by.x = "location_lower", by.y = "location_lower", all.x = TRUE)
    dat_match_subregions <- merge(dat_match1, subregions, by.x = "location_lower", by.y = "gadm1_lower", all.x = TRUE)
    
    ind_keys_regions <- which(!is.na(regions$location_var))
    for (j in ind_keys_regions) {
      location_var <- unlist(strsplit(regions$location_var[j], "; "))
      for (k in location_var) {
        ind_match <- which(dat_match_regions$location_lower == k)
        if (length(unique(regions$location[j])) > 1)
          cat(paste0("Warning: ", k, " matches multiple location names. Refine location_var!"))
        dat_match_regions$location[ind_match] <- regions$location[j]
        dat_match_regions$locationID[ind_match] <- regions$locationID[j]
      }
    }
    
    ind_keys_subregions <- which(!is.na(subregions$gadm1_var))
    for (j in ind_keys_subregions) {
      gadm1_var <- unlist(strsplit(subregions$gadm1_var[j], "; "))
      for (k in gadm1_var) {
        ind_match <- which(dat_match_subregions$location_lower == k)
        if (length(unique(subregions$gadm1_name[j])) > 1)
          cat(paste0("Warning: ", k, " matches multiple location names. Refine gadm1_var!"))
        dat_match_subregions$gadm1_name[ind_match] <- subregions$gadm1_name[j]
        dat_match_subregions$location[ind_match] <- subregions$location[j]
        dat_match_subregions$locationID[ind_match] <- subregions$locationID[j]
      }
    }
    
    dat_match1 <- full_join(dat_match_subregions,
                             dat_match_regions |> dplyr::select(order, locationID, location),
                             by = "order") |>
      mutate(locationID = coalesce(locationID.x, locationID.y),
             location = coalesce(location.x, location.y)) |>
      dplyr::select(-locationID.x, -locationID.y, -location.x, -location.y, -location_var, -gadm1_var)
    
    dat_match1 <- dat_match1[order(dat_match1$order), ]
    if (!identical(dat_match1$taxon_orig, dat$taxon_orig)) stop(paste("Data sets not sorted equally for", dataset_name))
    
    dat$locationID <- dat_match1$locationID
    dat$location <- dat_match1$location
    dat$stateProvince <- dat_match1$gadm1_name
    
    if (any(dat$location_orig %in% dup)) {
      matching_names <- unique(dat$location_orig[dat$location_orig %in% dup])
      warning(paste(
        "\n    Warning: Unresolved terms in ", dataset_name, ". The following location name(s) correspond to multiple subregions in the world:",
        paste(matching_names, collapse = ", "),
        ". Please modify the original location name(s) by including the country name in parentheses(), and try again (e.g: Amazonas (Colombia)) \n"
      ))
    }
    
    dat_regnames <- dat
    dat_regnames <- dat_regnames[!duplicated(dat_regnames), ]
    
    write_regnames <- dat_regnames |>
      dplyr::select(-c(stateProvince, locationID)) |>
      left_join(regions |> dplyr::select(location, locationID), by = "location")
    
    ## output ###############################################################
        missing <- dat_regnames$location_orig[is.na(dat_regnames$locationID)]
    clean_datasets[[dataset_name]] <- write_regnames
    if (length(missing) > 0) {
      missing_locations[[dataset_name]] <- sort(unique(missing))
    }
  }
  
  ## Post-processing: aggregate and export changed location names
  reg_names <- vector()
  for (dataset_name in names(clean_datasets)){
    dat <- clean_datasets[[dataset_name]]
    reg_names <- rbind(reg_names, cbind(dat[, c("location","location_orig")], origDB = dataset_name))
  }
  
  translated_locations <- NULL
  if (length(reg_names) > 0 && nrow(reg_names) > 0){
    reg_names <- reg_names[reg_names$location != reg_names$location_orig, ]
    reg_names <- unique(reg_names[order(reg_names$location), ])
    reg_names <- reg_names |> left_join(regions |> dplyr::select(location, locationID), by = "location")
    
    translated_locations <- reg_names
  }
  
  return(list(
    clean_datasets = clean_datasets,
    missing_locations = missing_locations,
    translated_locations = translated_locations
  ))
}

step2 <- StandardiseTerms(FileInfo = FileInfo)
step3 <- StandardiseLocationNames(FileInfo = FileInfo, step2_output = step2)

print(head(step3$clean_datasets[["SInAS"]]))
print(head(step3$missing_locations[["SInAS"]]))
print(head(step3$translated_locations))