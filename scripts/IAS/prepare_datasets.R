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

# Specifying column names for each dataset
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
      resolved_estabmeans <- unique(dat$establishmentMeans[!is.na(ind)]) # store matches
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
      resolved_occurrenceStatus <- unique(dat$occurrenceStatus[!is.na(ind)]) # store matches
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

CheckGBIFTax <- function(taxon_names=NULL,
                         column_name_taxa=NULL){
  
  ## check input variable
  if (is.null(taxon_names)){
    
    stop("No taxon names provided.")
    
  } else if (is.character(taxon_names)){ # check if input file is a vector
    
    dat <- as.data.frame(taxon_names)
    colnames(dat) <- "taxon_orig"
    
  } else if (is.data.frame(taxon_names)){ # check if input file is a data.frame
    
    dat <- taxon_names
    
  } else {
    
    stop("Cannot coerce data into data.frame. Please provide a data.frame or vector as input.")
    
  }
  
  if (!is.null(column_name_taxa)){ # check if column name of taxa provided
    
    colnames(dat)[colnames(dat)==column_name_taxa] <- "taxon_orig" # rename to standard column name
    
  }
  if (all(colnames(dat)!="taxon_orig")){ # check if column "taxon_orig" can be found
    
    stop("No column with taxon names found. Please specify in column_name_taxa.")
    
  }
  
  dat$scientificName <- NA
  dat$taxon <- dat$taxon_orig
  dat$GBIFstatus <- "MISSING"
  dat$GBIFmatchtype <- NA
  dat$GBIFnote <- NA
  dat$GBIFstatus_Synonym <- NA
  dat$species <- NA
  dat$genus <- NA
  dat$family <- NA
  dat$class <- NA
  dat$order <- NA
  dat$phylum <- NA
  dat$kingdom <- NA 
  dat$GBIFtaxonRank <- NA
  dat$GBIFusageKey <- NA
  
  kingdom_user_col <- intersect(c("kingdom_user", "Kingdom_user"), colnames(dat))
  kingdom_user_col <- if (length(kingdom_user_col) > 0) kingdom_user_col[[1]] else NA_character_
  
  if (!is.na(kingdom_user_col)){
    taxlist_lifeform <- unique(dat[,c("taxon", kingdom_user_col)])
    taxlist <- taxlist_lifeform$taxon
  } else if (any(colnames(dat)=="Author")){
    taxlist <- unique(paste(dat$taxon,dat$Author))
  } else {
    taxlist <- unique(dat$taxon)
  }
  n_taxa <- length(taxlist)

  #setup progress bar
  pb <- txtProgressBar(min=0, max=n_taxa, initial=0,style = 3)
  
  options(warn=-1) # the use of 'tibbles' data frame generates warnings as a bug; if solved this options() should be turned off
  
  mismatches <- data.frame(taxon=NA,status=NA,matchType=NA)
  for (j in 1:n_taxa){# loop over all species names; takes some hours...
    
    # select species name and download taxonomy
    ind_tax <- which(dat$taxon==taxlist[j])
    db_all <- name_backbone_verbose(taxlist[j],strict=T) # check for names and synonyms
    db <- db_all[["data"]]
    alternatives <- db_all$alternatives
    
    if (any(db$status=="ACCEPTED" & db$matchType=="EXACT" & colnames(db)=="canonicalName")){ 
      
      ### EXACT MATCHES: select only accepted names and exact matches ##############################################
      
      dat$taxon[ind_tax]      <- db[db$status=="ACCEPTED" & db$matchType=="EXACT",]$canonicalName[1]
      dat$scientificName[ind_tax] <- db[db$status=="ACCEPTED" & db$matchType=="EXACT",]$scientificName[1]
      dat$GBIFstatus[ind_tax]      <- db[db$status=="ACCEPTED" & db$matchType=="EXACT",]$status[1]
      dat$GBIFmatchtype[ind_tax]   <- db[db$status=="ACCEPTED" & db$matchType=="EXACT",]$matchType[1]
      dat$GBIFtaxonRank[ind_tax]        <- db[db$status=="ACCEPTED" & db$matchType=="EXACT",]$rank[1]
      dat$GBIFusageKey[ind_tax]        <- db[db$status=="ACCEPTED" & db$matchType=="EXACT",]$usageKey[1]
      
      try(dat$species[ind_tax]     <- db[db$status=="ACCEPTED" & db$matchType=="EXACT",]$species[1],silent=T)
      try(dat$genus[ind_tax]       <- db[db$status=="ACCEPTED" & db$matchType=="EXACT",]$genus[1],silent=T)
      try(dat$family[ind_tax]      <- db[db$status=="ACCEPTED" & db$matchType=="EXACT",]$family[1],silent=T)
      try(dat$class[ind_tax]       <- db[db$status=="ACCEPTED" & db$matchType=="EXACT",]$class[1],silent=T)
      try(dat$order[ind_tax]       <- db[db$status=="ACCEPTED" & db$matchType=="EXACT",]$order[1],silent=T)
      try(dat$phylum[ind_tax]      <- db[db$status=="ACCEPTED" & db$matchType=="EXACT",]$phylum[1],silent=T)
      try(dat$kingdom[ind_tax]     <- db[db$status=="ACCEPTED" & db$matchType=="EXACT",]$kingdom[1],silent=T)
      
      next # jump to next taxon
      
    } else if (any(db$status=="SYNONYM" & db$matchType=="EXACT" & colnames(db)=="species")) { # select synonyms
      
      ## SYNONYMS #################################################################################
      
      ## flag that it is a synonym
      dat$GBIFstatus[ind_tax] <- db[db$status=="SYNONYM" & db$matchType=="EXACT",]$status[1]
      dat$GBIFmatchtype[ind_tax] <- db[db$status=="SYNONYM" & db$matchType=="EXACT",]$matchType[1]
      dat$GBIFtaxonRank[ind_tax]     <- db[db$status=="SYNONYM" & db$matchType=="EXACT",]$rank[1]
      dat$GBIFusageKey[ind_tax]     <- db[db$status=="SYNONYM" & db$matchType=="EXACT",]$usageKey[1]
      
      ## check if accepted name is provided in 'alternatives'
      if (any(alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT")){
        
        if (nrow(alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",])>1) {
          dat$GBIFnote[ind_tax] <- "No single accepted name in GBIF"  # !!! new string
        } 
        
        dat$scientificName[ind_tax] <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$scientificName[1]
        dat$taxon[ind_tax]          <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$canonicalName[1]
        
        try(dat$species[ind_tax]     <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$species[1],silent=T)
        try(dat$genus[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$genus[1],silent=T)
        try(dat$family[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$family[1],silent=T)
        try(dat$class[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$class[1],silent=T)
        try(dat$order[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$order[1],silent=T)
        try(dat$phylum[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$phylum[1],silent=T)
        try(dat$kingdom[ind_tax]     <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$kingdom[1],silent=T)
        
        next # jump to next taxon
        
      } else if (db$rank=="SPECIES"){  ## try to get author name of synonym (not provided in 'db')(works only for species)

        dat$taxon[ind_tax]    <- db[db$status=="SYNONYM" & db$matchType=="EXACT",]$species[1]
        dat$GBIFstatus[ind_tax]    <- db[db$status=="SYNONYM" & db$matchType=="EXACT",]$status[1]
        dat$GBIFmatchtype[ind_tax] <- db[db$status=="SYNONYM" & db$matchType=="EXACT",]$matchType[1]
        dat$GBIFtaxonRank[ind_tax]      <- db[db$status=="SYNONYM" & db$matchType=="EXACT",]$rank[1]
        dat$GBIFusageKey[ind_tax]      <- db[db$status=="SYNONYM" & db$matchType=="EXACT",]$usageKey[1]
        
        db_all_2 <- name_backbone_verbose(dat$taxon[ind_tax][1],strict=T) # get scientific name
        db_2 <- db_all_2[["data"]]

        if (db_2$matchType=="EXACT"){ # exact matches
          dat$scientificName[ind_tax]  <- db_2[db_2$matchType=="EXACT",]$scientificName[1]
          dat$GBIFstatus_Synonym[ind_tax]<- db_2[db_2$matchType=="EXACT",]$status[1]
          try(dat$species[ind_tax]     <- db_2[db_2$matchType=="EXACT",]$species[1],silent=T)
          try(dat$genus[ind_tax]       <- db_2[db_2$matchType=="EXACT",]$genus[1],silent=T)
          try(dat$family[ind_tax]      <- db_2[db_2$matchType=="EXACT",]$family[1],silent=T)
          try(dat$class[ind_tax]       <- db_2[db_2$matchType=="EXACT",]$class[1],silent=T)
          try(dat$order[ind_tax]       <- db_2[db_2$matchType=="EXACT",]$order[1],silent=T)
          try(dat$phylum[ind_tax]      <- db_2[db_2$matchType=="EXACT",]$phylum[1],silent=T)
          try(dat$kingdom[ind_tax]     <- db_2[db_2$matchType=="EXACT",]$kingdom[1],silent=T)
        }
      }
      next
      
    } else if (any(db$status=="ACCEPTED" & db$matchType=="FUZZY" & db$confidence==100 & colnames(db)=="canonicalName")) { 

      ## FUZZY MATCHES #################################################################################
      
      dat$taxon[ind_tax]      <- db[db$status=="ACCEPTED" & db$matchType=="FUZZY",]$canonicalName[1]
      dat$scientificName[ind_tax] <- db[db$status=="ACCEPTED" & db$matchType=="FUZZY",]$scientificName[1]
      dat$GBIFstatus[ind_tax]      <- db[db$status=="ACCEPTED" & db$matchType=="FUZZY",]$status[1]
      dat$GBIFmatchtype[ind_tax]   <- db[db$status=="ACCEPTED" & db$matchType=="FUZZY",]$matchType[1]
      dat$GBIFtaxonRank[ind_tax]        <- db[db$status=="ACCEPTED" & db$matchType=="FUZZY",]$rank[1]
      dat$GBIFusageKey[ind_tax]        <- db[db$status=="ACCEPTED" & db$matchType=="FUZZY",]$usageKey[1]
      
      dat$scientificName[ind_tax] <- db[db$status=="ACCEPTED" & db$matchType=="FUZZY",]$scientificName[1]
      try(dat$species[ind_tax] <-db[db$status=="ACCEPTED" & db$matchType=="FUZZY",]$species[1],silent=T)
      try(dat$genus[ind_tax]   <-  db[db$status=="ACCEPTED" & db$matchType=="FUZZY",]$genus[1],silent=T)
      try(dat$family[ind_tax]  <- db[db$status=="ACCEPTED" & db$matchType=="FUZZY",]$family[1],silent=T)
      try(dat$class[ind_tax]   <- db[db$status=="ACCEPTED" & db$matchType=="FUZZY",]$class[1],silent=T)
      try(dat$order[ind_tax]   <- db[db$status=="ACCEPTED" & db$matchType=="FUZZY",]$order[1],silent=T)
      try(dat$phylum[ind_tax]  <- db[db$status=="ACCEPTED" & db$matchType=="FUZZY",]$phylum[1],silent=T)
      try(dat$kingdom[ind_tax] <- db[db$status=="ACCEPTED" & db$matchType=="FUZZY",]$kingdom[1],silent=T)
      
      next # jump to next taxon
      
    } else if (any(alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT") & any(colnames(alternatives)=="species")){

      if (length(unique(alternatives$phylum))>1){ # check whether entry exists for different phyla; likely indicates a homonym
        
        ## case: multiple accepted names in "alternatives" from different phyla
        
        ## HOMONYMS #################################################################################
        ## check for alternative names because of e.g. multiple entries for different taxonomic groups in GBIF...
        
        dat$GBIFnote[ind_tax]        <- "Homonym in GBIF"
        
        ## check information of kingdom provided by user and selected respective author
        if (!is.na(kingdom_user_col)) {
          if (length(unique(alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom==taxlist_lifeform[j,2],]$family))>1) print(paste(taxlist[j],"name occurrs in more than one family! To resolve this, you may provide information about author in original database, or kingdom or taxonomic group in DatabaseInfo.xlsx."))
          
          dat$taxon[ind_tax] <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$species[1]
          
          dat$scientificName[ind_tax] <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom==taxlist_lifeform[j,2],]$scientificName[1]
          dat$GBIFstatus[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom==taxlist_lifeform[j,2],]$status[1]
          dat$GBIFmatchtype[ind_tax]   <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom==taxlist_lifeform[j,2],]$matchType[1]
          dat$GBIFtaxonRank[ind_tax]        <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom==taxlist_lifeform[j,2],]$rank[1]
          dat$GBIFusageKey[ind_tax]        <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom==taxlist_lifeform[j,2],]$usageKey[1]

          try(dat$species[ind_tax]     <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom==taxlist_lifeform[j,2],]$species[1],silent=T)
          try(dat$genus[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom==taxlist_lifeform[j,2],]$genus[1],silent=T)
          try(dat$family[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom==taxlist_lifeform[j,2],]$family[1],silent=T)
          try(dat$class[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom==taxlist_lifeform[j,2],]$class[1],silent=T)
          try(dat$order[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom==taxlist_lifeform[j,2],]$order[1],silent=T)
          try(dat$phylum[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom==taxlist_lifeform[j,2],]$phylum[1],silent=T)
          try(dat$kingdom[ind_tax]     <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom==taxlist_lifeform[j,2],]$kingdom[1],silent=T)
          
          next
        }
        
        ## select entries from cross-taxonomic databases from certain taxa
        if (any(colnames(dat)=="Taxon_group")) { # !!!!! new line
          if (unique(dat$Taxon_group)!="All"){ # check if 'Taxon_group' provides useful information
            if (grepl("Vascular plants",unique(dat$Taxon_group))){ # case of vascular plants
              
              dat$taxon[ind_tax] <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$species[1]
              
              dat$scientificName[ind_tax] <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom=="Plantae",]$scientificName[1]
              dat$GBIFstatus[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom=="Plantae",]$status[1]
              dat$GBIFmatchtype[ind_tax]   <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom=="Plantae",]$matchType[1]
              dat$GBIFtaxonRank[ind_tax]        <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom=="Plantae",]$rank[1]
              dat$GBIFusageKey[ind_tax]        <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom=="Plantae",]$usageKey[1]
  
              try(dat$species[ind_tax]     <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom=="Plantae",]$species[1],silent=T)
              try(dat$genus[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom=="Plantae",]$genus[1],silent=T)
              try(dat$family[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom=="Plantae",]$family[1],silent=T)
              try(dat$class[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom=="Plantae",]$class[1],silent=T)
              try(dat$order[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom=="Plantae",]$order[1],silent=T)
              try(dat$phylum[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom=="Plantae",]$phylum[1],silent=T)
              try(dat$kingdom[ind_tax]     <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom=="Plantae",]$kingdom[1],silent=T)
            }
            if (grepl("Reptiles",unique(dat$Taxon_group))){
              
              dat$taxon[ind_tax] <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$species[1]
              
              dat$scientificName[ind_tax] <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Reptilia",]$scientificName[1]
              dat$GBIFstatus[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Reptilia",]$status[1]
              dat$GBIFmatchtype[ind_tax]   <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Reptilia",]$matchType[1]
              dat$GBIFtaxonRank[ind_tax]            <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Reptilia",]$rank[1]
              dat$GBIFusageKey[ind_tax]            <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Reptilia",]$usageKey[1]
  
              try(dat$species[ind_tax]     <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Reptilia",]$species[1],silent=T)
              try(dat$genus[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Reptilia",]$genus[1],silent=T)
              try(dat$family[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Reptilia",]$family[1],silent=T)
              try(dat$class[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Reptilia",]$class[1],silent=T)
              try(dat$order[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Reptilia",]$order[1],silent=T)
              try(dat$phylum[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Reptilia",]$phylum[1],silent=T)
              try(dat$kingdom[ind_tax]     <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Reptilia",]$kingdom[1],silent=T)
            }
            if (grepl("Amphibians",unique(dat$Taxon_group))){
              
              dat$taxon[ind_tax] <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$species[1]
              
              dat$scientificName[ind_tax] <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Amphibia",]$scientificName[1]
              dat$GBIFstatus[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Amphibia",]$status[1]
              dat$GBIFmatchtype[ind_tax]   <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Amphibia",]$matchType[1]
              dat$GBIFtaxonRank[ind_tax]            <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Amphibia",]$rank[1]
              dat$GBIFusageKey[ind_tax]            <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Amphibia",]$usageKey[1]
  
              try(dat$species[ind_tax]     <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Amphibia",]$species[1],silent=T)
              try(dat$genus[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Amphibia",]$genus[1],silent=T)
              try(dat$family[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Amphibia",]$family[1],silent=T)
              try(dat$class[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Amphibia",]$class[1],silent=T)
              try(dat$order[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Amphibia",]$order[1],silent=T)
              try(dat$phylum[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Amphibia",]$phylum[1],silent=T)
              try(dat$kingdom[ind_tax]     <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Amphibia",]$kingdom[1],silent=T)
            }
            if (grepl("Birds",unique(dat$Taxon_group))){
              
              dat$taxon[ind_tax] <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$species[1]
              
              dat$scientificName[ind_tax] <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Aves",]$scientificName[1]
              dat$GBIFstatus[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Aves",]$status[1]
              dat$GBIFmatchtype[ind_tax]   <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Aves",]$matchType[1]
              dat$GBIFtaxonRank[ind_tax]        <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Aves",]$rank[1]
              dat$GBIFusageKey[ind_tax]        <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Aves",]$usageKey[1]
  
              try(dat$species[ind_tax]     <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Aves",]$species[1],silent=T)
              try(dat$genus[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Aves",]$genus[1],silent=T)
              try(dat$family[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Aves",]$family[1],silent=T)
              try(dat$class[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Aves",]$class[1],silent=T)
              try(dat$order[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Aves",]$order[1],silent=T)
              try(dat$phylum[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Aves",]$phylum[1],silent=T)
              try(dat$kingdom[ind_tax]     <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Aves",]$kingdom[1],silent=T)
            }
            if (grepl("Insects",unique(dat$Taxon_group))){
              
              dat$taxon[ind_tax] <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$species[1]
              
              dat$scientificName[ind_tax] <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Insecta",]$scientificName[1]
              dat$GBIFstatus[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Insecta",]$status[1]
              dat$GBIFmatchtype[ind_tax]   <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Insecta",]$matchType[1]
              dat$GBIFtaxonRank[ind_tax]        <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Insecta",]$rank[1]
              dat$GBIFusageKey[ind_tax]        <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Insecta",]$usageKey[1]
  
              try(dat$species[ind_tax]     <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Insecta",]$species[1],silent=T)
              try(dat$genus[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Insecta",]$genus[1],silent=T)
              try(dat$family[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Insecta",]$family[1],silent=T)
              try(dat$class[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Insecta",]$class[1],silent=T)
              try(dat$order[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Insecta",]$order[1],silent=T)
              try(dat$phylum[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Insecta",]$phylum[1],silent=T)
              try(dat$kingdom[ind_tax]     <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Insecta",]$kingdom[1],silent=T)
            }
            if (grepl("Mammals",unique(dat$Taxon_group))){
              
              dat$taxon[ind_tax] <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$species[1]
              
              dat$scientificName[ind_tax] <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Mammalia",]$scientificName[1]
              dat$GBIFstatus[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Mammalia",]$status[1]
              dat$GBIFmatchtype[ind_tax]   <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Mammalia",]$matchType[1]
              dat$GBIFtaxonRank[ind_tax]        <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Mammalia",]$rank[1]
              dat$GBIFusageKey[ind_tax]        <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Mammalia",]$usageKey[1]
  
              try(dat$species[ind_tax]     <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Mammalia",]$species[1],silent=T)
              try(dat$genus[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Mammalia",]$genus[1],silent=T)
              try(dat$family[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Mammalia",]$family[1],silent=T)
              try(dat$class[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Mammalia",]$class[1],silent=T)
              try(dat$order[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Mammalia",]$order[1],silent=T)
              try(dat$phylum[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Mammalia",]$phylum[1],silent=T)
              try(dat$kingdom[ind_tax]     <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Mammalia",]$kingdom[1],silent=T)
            }
          }
        } # !!!!! new line
      } else {
        
        ## case: a single accepted name in "alternatives" 

        dat$taxon[ind_tax] <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$species[1]
        
        dat$scientificName[ind_tax]  <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$scientificName[1]
        dat$GBIFstatus[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$status[1]
        dat$GBIFmatchtype[ind_tax]   <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$matchType[1]
        dat$GBIFtaxonRank[ind_tax]   <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$rank[1]
        dat$GBIFusageKey[ind_tax]    <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$usageKey[1]

        dat$GBIFnote[ind_tax]        <- "Accepted name provided in 'alternative names' in GBIF"
        
        try(dat$species[ind_tax]     <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$species[1],silent=T)
        try(dat$genus[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$genus[1],silent=T)
        try(dat$family[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$family[1],silent=T)
        try(dat$class[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$class[1],silent=T)
        try(dat$order[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$order[1],silent=T)
        try(dat$phylum[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$phylum[1],silent=T)
        try(dat$kingdom[ind_tax]     <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$kingdom[1],silent=T)
        
        next # jump to next taxon
        
      }
    } else if (any(alternatives$status=="SYNONYM" & alternatives$matchType=="EXACT" & any(colnames(alternatives)=="species"))) { # check for synonyms in 'alternatives'

      ## check alternative names #################################################################################
      
      if (nrow(alternatives[alternatives$status=="SYNONYM" & alternatives$matchType=="EXACT",])>1) { # check if multiple synonyms are provided; if so leave to next taxon
        dat$GBIFnote[ind_tax] <- "No single accepted name in GBIF" # !!!! new string
        next # not possible to identify correct name
      } 
      
      dat$taxon[ind_tax]       <- alternatives[alternatives$status=="SYNONYM" & alternatives$matchType=="EXACT",]$species[1]
      dat$GBIFstatus[ind_tax]       <- alternatives[alternatives$status=="SYNONYM" & alternatives$matchType=="EXACT",]$status[1]
      dat$GBIFmatchtype[ind_tax]   <- alternatives[alternatives$status=="SYNONYM" & alternatives$matchType=="EXACT",]$matchType[1]
      dat$GBIFtaxonRank[ind_tax]            <- alternatives[alternatives$status=="SYNONYM" & alternatives$matchType=="EXACT",]$rank[1]
      dat$GBIFusageKey[ind_tax]            <- alternatives[alternatives$status=="SYNONYM" & alternatives$matchType=="EXACT",]$usageKey[1]

      dat$GBIFnote[ind_tax] <- "Synonym without an exact match of an accepted name on GBIF"  # set as default in this case; potentially over-written in next step
      
      ## try to get author name of synonym (not provided in 'db')
      db_all_2 <- name_backbone_verbose(dat$taxon[ind_tax][1])
      db_2 <- db_all_2[["data"]]
      
      if (db_2$status=="ACCEPTED" & db_2$matchType=="EXACT"){
        
        if (length(unique(db_2[db_2$status=="ACCEPTED" & db_2$matchType=="EXACT",]$family))>1) cat(paste0("\n Warning: Multiple entries of ",dat$scientificName[ind_tax]," found in GBIF! Add author to species name or add kingdom information to original database or check GBIF. \n"))
        
        dat$scientificName[ind_tax] <- db_2[db_2$status=="ACCEPTED" & db_2$matchType=="EXACT",]$scientificName[1]
        
        try(dat$species[ind_tax]     <- db_2[db_2$status=="ACCEPTED" & db_2$matchType=="EXACT",]$species[1],silent=T)
        try(dat$genus[ind_tax]       <- db_2[db_2$status=="ACCEPTED" & db_2$matchType=="EXACT",]$genus[1],silent=T)
        try(dat$family[ind_tax]      <- db_2[db_2$status=="ACCEPTED" & db_2$matchType=="EXACT",]$family[1],silent=T)
        try(dat$class[ind_tax]       <- db_2[db_2$status=="ACCEPTED" & db_2$matchType=="EXACT",]$class[1],silent=T)
        try(dat$order[ind_tax]       <- db_2[db_2$status=="ACCEPTED" & db_2$matchType=="EXACT",]$order[1],silent=T)
        try(dat$phylum[ind_tax]      <- db_2[db_2$status=="ACCEPTED" & db_2$matchType=="EXACT",]$phylum[1],silent=T)
        try(dat$kingdom[ind_tax]     <- db_2[db_2$status=="ACCEPTED" & db_2$matchType=="EXACT",]$kingdom[1],silent=T)

        dat$GBIFnote[ind_tax] <- "Accepted name found on GBIF"
      }
      
      next # jump to next taxon

    } else {
      mismatches <- rbind(mismatches,c(taxlist[j],NA,NA))
      try(mismatches$status[nrow(mismatches)] <- db$status,silent = T)
      try(mismatches$matchType[nrow(mismatches)] <- db$matchType,silent = T)
    }

    #update progress bar
    info <- sprintf("%d%% done", round((j/n_taxa)*100))
    setTxtProgressBar(pb, j, label=info)
  }
  close(pb)

  options(warn=0) # the use of 'tibbles' data frame generates warnings as a bug; if solved this options() should be turned off
  
  # dat <- dat[!is.na(dat$GBIFstatus),] # remove species not resolved in GBIF

  out <- list()
  out[[1]] <- dat
  out[[2]] <- mismatches

  return(out)
}

StandardiseTaxonNames <- function(FileInfo = NULL, step3_output = NULL){

  inputfiles <- step3_output$clean_datasets
  clean_datasets <- list()
  missing_taxa <- list()
  fullspeclist <- NULL
  
  taxon_list_cols <- c(
    "taxon_orig", "taxon", "scientificName", "GBIFstatus",
    "GBIFstatus_Synonym", "GBIFmatchtype", "GBIFtaxonRank",
    "GBIFusageKey", "GBIFnote", "species", "genus", "family",
    "order", "class", "phylum", "kingdom"
  )
  drop_gbif_cols <- c(
    "GBIFstatus", "GBIFmatchtype", "GBIFtaxonRank", "GBIFusageKey",
    "GBIFnote", "GBIFstatus_Synonym", "species", "genus", "family",
    "class", "order", "phylum", "kingdom"
  )

  for (i in seq_along(inputfiles)){
    
    dat <- inputfiles[[i]]
    dataset_name <- names(inputfiles)[i]
    
    # remove white space #######################################
    dat$taxon_orig <- gsub("  "," ",dat$taxon_orig)
    dat$taxon_orig <- gsub("^\\s+|\\s+$", "",dat$taxon_orig) # trim leading and trailing whitespace
    dat$taxon_orig <- gsub("[$\xc2\xa0]", " ",dat$taxon_orig) # replace weird white space with recognised white space
    dat$taxon_orig <- gsub("  "," ",dat$taxon_orig)
    dat$taxon_orig <- gsub("\n"," ",dat$taxon_orig)
    
    dat <- dat[!is.na(dat$taxon_orig),]
    dat <- dat[dat$taxon_orig!="",]
    
    #### check names using 'rgbif' GBIF taxonomy ###########
    cat(paste0("\n    Working on ",dataset_name,"... \n"))
    checked_taxa <- CheckGBIFTax(dat)
    
    DB <- checked_taxa[[1]]
    mismatches <- checked_taxa[[2]]
    mismatches <- mismatches[!(is.na(mismatches$taxon) & is.na(mismatches$status) & is.na(mismatches$matchType)),]
    
    ## collect full species list with original names and names assigned by GBIF
    present_taxon_list_cols <- taxon_list_cols[taxon_list_cols %in% colnames(DB)]
    fullspeclist <- rbind(fullspeclist, unique(DB[, present_taxon_list_cols, drop = FALSE]))
    
    DB <- unique(DB) # remove duplicates
    DB$GBIFstatus[is.na(DB$GBIFstatus)] <- "NoMatch"
    DB <- DB[, !colnames(DB) %in% drop_gbif_cols, drop = FALSE]
    
    if (!is.null(mismatches) && nrow(mismatches) > 0){
      oo <- order(mismatches$taxon)
      missing_taxa[[dataset_name]] <- unique(mismatches[oo,])
    }
    
    clean_datasets[[dataset_name]] <- DB
  }
  
  if (is.null(fullspeclist) || nrow(fullspeclist) == 0) {
    return(list(
      clean_datasets = clean_datasets,
      missing_taxa = missing_taxa,
      full_taxa_list = NULL
    ))
  }
  
  oo <- order(fullspeclist$kingdom, fullspeclist$phylum, fullspeclist$class, fullspeclist$order, fullspeclist$taxon)
  fullspeclist <- unique(fullspeclist[oo,])
  
  ## assign taxon ID unique to individual taxa #############
  ## identify unique taxa (obtained from GBIF)
  fullspeclist$sequence <- 1:nrow(fullspeclist)
  uni_taxa <- unique(fullspeclist$scientificName)
  uni_taxa <- data.frame(scientificName = uni_taxa[!is.na(uni_taxa)], stringsAsFactors = FALSE)
  uni_taxa$taxonID <- 1:nrow(uni_taxa)

  ## merge taxonID with full taxa list
  fullspeclist_2 <- merge(fullspeclist, uni_taxa, by = "scientificName", all = TRUE)
  missing_taxon_id <- which(is.na(fullspeclist_2$taxonID))
  if (length(missing_taxon_id) > 0) {
    max_taxon_id <- max(fullspeclist_2$taxonID, na.rm = TRUE)
    if (!is.finite(max_taxon_id)) max_taxon_id <- 0
    fullspeclist_2$taxonID[missing_taxon_id] <- seq_along(missing_taxon_id) + max_taxon_id
  }
  
  fullspeclist_2 <- fullspeclist_2[order(fullspeclist_2$sequence),]
  fullspeclist_2 <- fullspeclist_2[, colnames(fullspeclist_2) != "sequence", drop = FALSE]
  
  ## add taxon ID to data sets ##########
  taxon_id <- unique(fullspeclist_2[,c("taxonID","taxon_orig")])
  for (dataset_name in names(clean_datasets)){
    clean_datasets[[dataset_name]] <- merge(clean_datasets[[dataset_name]], taxon_id, by = "taxon_orig", all.x = TRUE)
  }
  
  return(list(
    clean_datasets = clean_datasets,
    missing_taxa = missing_taxa,
    full_taxa_list = fullspeclist_2
  ))
}


GeteventDate <- function(FileInfo = NULL, step3_output = NULL){
  
  inputfiles <- step3_output$clean_datasets
  replacements <- read.xlsx("/scripts/IAS/Config/Guidelines_eventDates.xlsx")
  replacements$Entry <- as.character(replacements$Entry)
  replacements$Replacement <- as.character(replacements$Replacement)
  replacements$Replacement[is.na(replacements$Replacement)] <- ""
  
  clean_datasets <- list()
  nonnumeric_eventDates <- list()
  translated_eventDates <- list()
  
  values_differ <- function(x, y) {
    x <- ifelse(is.na(x), "", as.character(x))
    y <- ifelse(is.na(y), "", as.character(y))
    x != y
  }
  
  standardise_event_date <- function(x) {
    x <- as.character(x)
    x[is.na(x)] <- ""
    for (j in 1:nrow(replacements)) {
      if (!is.na(replacements$Entry[j])) {
        x[x == replacements$Entry[j]] <- as.character(replacements$Replacement[j])
      }
    }
    gsub("^\\s+|\\s+$", "", x)
  }
  
  for (i in seq_along(inputfiles)){
    
    dat <- inputfiles[[i]]
    dataset_name <- names(inputfiles)[i]
    nonnumeric <- vector()
    
    ## treat first records #############
    if (any(colnames(dat)=="eventDate")){ 
      
      dat$eventDate_orig <- dat$eventDate # keep original entry
      dat$eventDate <- standardise_event_date(dat$eventDate)
      
      ## test if all first records can be transferred to numeric
      firstrec_test <- dat$eventDate[dat$eventDate != ""]
      suppressWarnings( first2 <- as.numeric(firstrec_test)) # default warning is confusing; print meaningful warning below instead
      if (any(is.na(first2))){
        nonnumeric <- unique(firstrec_test[is.na(first2)]) # collect non-numeric entries
      } 
      
      ## convert first records to numeric
      suppressWarnings( dat$eventDate <- as.numeric(dat$eventDate))
    
      ## treat second first record if available #############
      if (any(colnames(dat)=="eventDate2")){
        
        dat$eventDate2_orig <- dat$eventDate2 # keep original entry
        dat$eventDate2 <- standardise_event_date(dat$eventDate2)
        
        ## test if all first records can be transferred to numeric
        firstrec_test <- dat$eventDate2[dat$eventDate2 != ""]
        suppressWarnings( first2 <- as.numeric(firstrec_test))
        if (any(is.na(first2))){
          nonnumeric <- c(nonnumeric,unique(firstrec_test[is.na(first2)])) # collect non-numeric entries
        } 
    
        ## convert first records to numeric
        suppressWarnings( dat$eventDate2 <- as.numeric(dat$eventDate2))
        
        ## calculate unique first record if two are provided
        ## if range between two first records > 1, take mean of both first records; otherwise, take the earliest (keep the one provided in 'eventDate')
        diff_records <- which((dat$eventDate2 - dat$eventDate)>0) # difference to check
        dat$eventDate[diff_records] <- round(rowMeans(dat[diff_records,c("eventDate","eventDate2")]))
      } 
      
      ## prepare output #####
      if (any(colnames(dat)=="eventDate2")){
        changed <- values_differ(dat$eventDate, dat$eventDate_orig) | values_differ(dat$eventDate2, dat$eventDate2_orig)
        out_translated <- unique(dat[changed,c("eventDate","eventDate2","eventDate_orig","eventDate2_orig")])
        if (nrow(out_translated)>0){  # avoid situation of adding empty data sets
          out_translated$note <- NA
          ind <- (out_translated$eventDate2 - out_translated$eventDate)<0
          out_translated[which(ind),]$note <- "eventDate2 lies before eventDate"
          out_translated$origDB  <- dataset_name
          out_translated <- out_translated[,c("eventDate","eventDate2","eventDate_orig","eventDate2_orig","note","origDB")]
        }
      } else {
        changed <- values_differ(dat$eventDate, dat$eventDate_orig)
        out_translated <- unique(dat[changed,c("eventDate","eventDate_orig")])
        if (nrow(out_translated)>0){  # avoid situation of adding empty data sets
          out_translated$eventDate2 <- NA
          out_translated$eventDate2_orig <- NA
          out_translated$note <- NA
          out_translated$origDB  <- dataset_name
          out_translated <- out_translated[,c("eventDate","eventDate2","eventDate_orig","eventDate2_orig","note","origDB")]
        }
      }
      if (nrow(out_translated)>0){
        translated_eventDates[[dataset_name]] <- out_translated
      }
    }    

    ## Output #######################################
    
    if (length(nonnumeric)>0){
      warning(paste("\n    Warning: First records in",dataset_name,"contain non-numeric symbols. Converted to missing values. \n"))
      nonnumeric_eventDates[[dataset_name]] <- sort(unique(nonnumeric))
    } 

    clean_datasets[[dataset_name]] <- dat
  }
  
  all_translated <- NULL
  if (length(translated_eventDates) > 0){
    all_translated <- unique(do.call("rbind",translated_eventDates))
  }
  
  return(list(
    clean_datasets = clean_datasets,
    nonnumeric_eventDates = nonnumeric_eventDates,
    translated_eventDates = all_translated
  ))
}

step2 <- StandardiseTerms(FileInfo = FileInfo)
step3 <- StandardiseLocationNames(FileInfo = FileInfo, step2_output = step2)
step4 <- StandardiseTaxonNames(FileInfo = FileInfo, step3_output = step3)
step5 <- GeteventDate(FileInfo = FileInfo, step3_output = step4)
print("*************clean datasets*************")
print(head(step5$clean_datasets[["GRIIS"]]))
print("*************missing locations*************")
print(head(step3$missing_locations[["GRIIS"]]))
print("*************translated locations*************")
print(head(step3$translated_locations))
print("*************missing taxa*************")
print(head(step4$missing_taxa[["GRIIS"]]))
print("*************non-numeric event dates*************")
print(head(step5$nonnumeric_eventDates[["GRIIS"]]))
print("*************translated event dates*************")
print(head(step5$translated_eventDates))

griis_clean <- step5$clean_datasets[["GRIIS"]]
first_records_clean <- step5$clean_datasets[["FirstRecords"]]

griis_path <- file.path(outputFolder, "GRIIS_clean.csv")
first_records_path <- file.path(outputFolder, "FirstRecords_clean.csv")
file_info_path <- file.path(outputFolder, "FileInfo.csv")

write.csv(griis_clean, griis_path, row.names = FALSE)
write.csv(first_records_clean, first_records_path, row.names = FALSE)
write.csv(FileInfo, file_info_path, row.names = FALSE)

biab_output("griis_clean", griis_path)
biab_output("first_records_clean", first_records_path)
biab_output("file_info", file_info_path)

