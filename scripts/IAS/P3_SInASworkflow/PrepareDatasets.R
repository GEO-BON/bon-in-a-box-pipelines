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


input <- biab_inputs()
country_name <- input$country_name$country$englishName

griis <- read.csv(input$griis_checklist)
firstrecords <- read.csv(input$first_records)
#griis <- read.csv("C:/Users/Samara/Desktop/bon-in-a-box-pipelines/output/IAS/P1_ChecklistDownload/download_checklist/24WCclDWWTOfF_TezBFTZE32-OPe/GRIIS_checklist.csv")
#firstrecords <- read.csv("C:/Users/Samara/Desktop/bon-in-a-box-pipelines/output/IAS/P2_FirstRecordsData/standardise_data/MvoeUdjrbO9xW2gLxy9qcQhDgtHB/FirstRecords_cleaned.csv")


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


datasets_in <- list(GRIIS = GRIIS, FirstRecords = FirstRecords)



PrepareDatasets <- function(datasets_in=NULL){

  if (is.null(datasets_in)) {
    if (!exists("datasets", inherits = TRUE)) {
      stop("No datasets found. Provide 'datasets_in' or define a non-empty global 'datasets' list.")
    }
    datasets_in <- get("datasets", inherits = TRUE)
    if (length(datasets_in) == 0) {
      stop("No datasets found. Provide 'datasets_in' or define a non-empty global 'datasets' list.")
    }
  }

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

  if (!exists("outputFolder")) {
    stop("outputFolder is not available in this runtime.")
  }
  
  ## create output folder #####

  ######## Load data sets ########################################################
  
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
    dat_out[is.null(dat_out)] <- ""
    dat_out[is.na(dat_out)] <- ""
    
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
    
    clean_path <- file.path(outputFolder, paste("Step1_StandardColumns_",FileInfo[i,"Dataset_brief_name"],".csv",sep=""))
    write.csv(dat_out, clean_path, row.names = FALSE)
    output_name <- paste0(
      "step1_standardcolumns_",
      gsub("[^[:alnum:]_]+", "_", tolower(as.character(FileInfo[i, "Dataset_brief_name"])))
    )
      biab_output(output_name, clean_path)
  }

  invisible(FileInfo)
}


PrepareDatasets(datasets_in = datasets_in)