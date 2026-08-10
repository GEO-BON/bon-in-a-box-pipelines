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

selected_filter_values <- function(values, label) {
  values <- unique(trimws(as.character(unlist(values, use.names = FALSE))))
  values <- values[!is.na(values) & nzchar(values)]
  if (length(values) == 0) {
    stop("Select at least one ", label, " for the SInAS preparation step.")
  }
  values
}

selected_kingdoms <- selected_filter_values(input$kingdoms, "kingdom")
selected_habitats <- selected_filter_values(input$habitats, "habitat type")

# Match the original P3 country-level policy: First Records from every mapped
# region contribute to the parent country, while only the primary national
# GRIIS checklist defines the GRIIS species list. Set this to FALSE in a future
# strict-geography implementation to retain the original regional locations.
roll_up_first_records_to_parent <- TRUE

config_file <- function(filename) {
  candidates <- c(
    file.path("/scripts/IAS/Config", filename),
    file.path("scripts/IAS/Config", filename),
    file.path("Config", filename)
  )
  existing <- candidates[file.exists(candidates)]
  if (length(existing) == 0) {
    stop("Required SInAS configuration file was not found: ", filename)
  }
  existing[[1]]
}

read_input_table <- function(path, label) {
  if (is.null(path) || !file.exists(path)) {
    stop(label, " input does not exist: ", path)
  }
  dat <- read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  if (ncol(dat) == 1) {
    dat <- read.table(
      path, header = TRUE, stringsAsFactors = FALSE, check.names = FALSE
    )
  }
  dat
}

message("Running the SInAS cleaning workflow for ", country_name, " (", iso3, ").")

# Loading in datasets
griis <- read_input_table(input$griis_checklist, "GRIIS")
firstrecords <- read_input_table(input$first_records, "First Records")
#griis <- read.csv("C:/Users/Samara/Desktop/bon-in-a-box-pipelines/output/IAS/P1_ChecklistDownload/download_checklist/24WCclDWWTOfF_TezBFTZE32-OPe/GRIIS_checklist.csv")
#firstrecords <- read.csv("C:/Users/Samara/Desktop/bon-in-a-box-pipelines/output/IAS/P2_FirstRecordsData/standardise_data/MvoeUdjrbO9xW2gLxy9qcQhDgtHB/FirstRecords_cleaned.csv")

# Loading in config files

# GRIIS and First Records are produced by fixed upstream BON in a Box steps, so
# their source mappings are configuration, not user inputs. Optional known
# fields are used automatically when they are present.
validate_columns <- function(dat, required, dataset_name) {
  missing <- setdiff(required, names(dat))
  if (length(missing) > 0) {
    stop(
      dataset_name, " is missing expected columns: ",
      paste(missing, collapse = ", "),
      ". Check that the matching BON in a Box download step was used."
    )
  }
}
validate_columns(
  griis,
  c(
    "countryInCompendium", "checklistType", "checklistLevel", "kingdom",
    "habitat", "scientificName", "checklistName"
  ),
  "GRIIS"
)
validate_columns(
  firstrecords,
  c("kingdom", "habitat", "taxon", "location", "eventDate"),
  "First Records"
)

known_column <- function(dat, column) {
  if (column %in% names(dat)) column else NA_character_
}
known_additional <- function(dat, columns) {
  present <- intersect(columns, names(dat))
  if (length(present) == 0) NA_character_ else paste(present, collapse = "; ")
}

Dataset_brief_name <- c("GRIIS", "FirstRecords")
Taxon_group <- "All"
Column_recordID <- c("linkID", "linkID")
Column_taxon <- c("scientificName", "taxon")
Column_author <- c(NA_character_, NA_character_)
Column_scientificName <- c(NA_character_, NA_character_)
Column_location <- c("checklistName", "location")
Column_kingdom <- c("kingdom", "kingdom")
Column_country_ISO <- c(
  known_column(griis, "ISO3"), known_column(firstrecords, "ISO3")
)
Column_eventDate1 <- c(
  known_column(griis, "eventDate"), "eventDate"
)
Column_eventDate2 <- c(
  known_column(griis, "eventDate2"), known_column(firstrecords, "eventDate2")
)
Column_establishmentMeans <- c(
  known_column(griis, "establishmentMeans"),
  known_column(firstrecords, "establishmentMeans")
)
Column_occurrenceStatus <- c(
  known_column(griis, "occurrenceStatus"),
  known_column(firstrecords, "occurrenceStatus")
)
Column_degreeOfEstablishment <- c(
  known_column(griis, "degreeOfEstablishment"),
  known_column(firstrecords, "degreeOfEstablishment")
)
Column_pathway <- c(
  known_column(griis, "pathway"), known_column(firstrecords, "pathway")
)
Column_habitat <- c("habitat", "habitat")
Column_bibliographicCitation <- c(
  known_column(griis, "bibliographicCitation"),
  known_column(firstrecords, "bibliographicCitation")
)
Column_additional <- c(
  known_additional(
    griis,
    c("isInvasive", "isInvasiveInCountry", "isInvasiveAnywhere")
  ),
  known_additional(
    firstrecords,
    c(
      "taxaGroup", "sourceLocation", "sourceLocationID",
      "sourceVersion", "sourceDOI", "sourceFile"
    )
  )
)

# Filter GRIIS data set 
GRIIS <- griis %>% 
  dplyr::filter(countryInCompendium == TRUE) %>% 
  dplyr::filter(checklistType == "national") %>% 
  dplyr::filter(checklistLevel == "Primary") %>%
  dplyr::filter(kingdom %in% selected_kingdoms) %>%
  dplyr::filter(habitat %in% selected_habitats)

if (nrow(GRIIS) == 0) {
  stop(
    "No eligible GRIIS records remain for ", country_name,
    ". This workflow requires a national, Primary GRIIS checklist matching ",
    "the selected kingdoms (", paste(selected_kingdoms, collapse = ", "),
    ") and habitats (", paste(selected_habitats, collapse = ", "), ")."
  )
}

# Filter First Records data set 
FirstRecords <- firstrecords %>% 
  dplyr::filter(kingdom %in% selected_kingdoms) %>%
  dplyr::filter(habitat %in% selected_habitats)

# Confirm that the supplied First Records locations belong to the selected
# country according to the same mapping used by the original P3 workflow.
first_records_locations <- openxlsx::read.xlsx(
  config_file("AllLocations.xlsx"), sheet = 2, na.strings = ""
)
required_location_columns <- c("locationID", "ISO3", "gadm0_name")
missing_location_columns <- setdiff(
  required_location_columns, names(first_records_locations)
)
if (length(missing_location_columns) > 0) {
  stop(
    "AllLocations.xlsx is missing required columns: ",
    paste(missing_location_columns, collapse = ", ")
  )
}
country_location_map <- first_records_locations %>%
  dplyr::filter(ISO3 == iso3)
if (nrow(country_location_map) == 0) {
  stop("No First Records locations are mapped to selected ISO3 ", iso3, ".")
}
if (!"locationID" %in% names(firstrecords)) {
  stop(
    "First Records input must contain locationID so its country association ",
    "can be validated before P3 preparation."
  )
}
input_location_ids <- unique(as.character(firstrecords$locationID))
input_location_ids <- input_location_ids[
  !is.na(input_location_ids) & nzchar(trimws(input_location_ids))
]
allowed_location_ids <- unique(as.character(country_location_map$locationID))
unexpected_location_ids <- setdiff(input_location_ids, allowed_location_ids)
if (length(unexpected_location_ids) > 0) {
  stop(
    "First Records contains locationID values not mapped to ", country_name,
    " (", iso3, "): ", paste(unexpected_location_ids, collapse = ", ")
  )
}

## The source workflow creates country-specific IDs before standardisation. They
## are required to trace every QC decision back to the downloaded source row.
if (!"linkID" %in% names(GRIIS)) {
  GRIIS$linkID <- paste0(iso3, "_G", seq_len(nrow(GRIIS)))
}
if (!"linkID" %in% names(FirstRecords)) {
  FirstRecords$linkID <- paste0(iso3, "_F", seq_len(nrow(FirstRecords)))
}

#######################
## Step 1: Prepare datasets
#######################

# removing duplicates from a given country

 if ("taxonID" %in% colnames(FirstRecords) && any(duplicated(FirstRecords$taxonID))) {
    
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

# Preserve the source geography for traceability before reproducing the
# original P3 roll-up of regional first records to the parent country.
FirstRecords_COUNTRY <- FirstRecords_COUNTRY %>%
  dplyr::mutate(
    sourceLocation = as.character(location),
    sourceLocationID = as.character(locationID)
  )

if (roll_up_first_records_to_parent) {
  parent_location <- country_location_map$gadm0_name
  parent_location <- unique(
    parent_location[!is.na(parent_location) & nzchar(trimws(parent_location))]
  )
  if (length(parent_location) == 0) {
    stop("No parent-country gadm0_name is configured for ISO3 ", iso3, ".")
  }
  if (length(parent_location) > 1) {
    stop(
      "Multiple parent-country gadm0_name values are configured for ISO3 ",
      iso3, ": ", paste(parent_location, collapse = ", ")
    )
  }
  FirstRecords_COUNTRY$location <- parent_location[[1]]
}

# sourceLocation/sourceLocationID are created during the country roll-up, after
# the initial dynamic mappings are assembled, so refresh this optional mapping.
Column_additional[[2]] <- known_additional(
  FirstRecords_COUNTRY,
  c(
    "taxaGroup", "sourceLocation", "sourceLocationID",
    "sourceVersion", "sourceDOI", "sourceFile"
  )
)



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
      if (col_recordID %in% colnames(dat) && col_recordID != "linkID") {
        dat$linkID <- as.character(dat[[col_recordID]])
      }
      all_column_names <- c(all_column_names,"linkID")
    }
    
    if (!is.na(FileInfo[i,"Column_taxon"]) & FileInfo[i,"Column_taxon"]!=""){
      col_spec_names <- FileInfo[i,"Column_taxon"]
      all_column_names <- c(all_column_names, col_spec_names)
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
      all_column_names <- c(all_column_names, col_spec_names)
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
      if (exists("col_establishmentMeans") && col_establishmentMeans==col_occurrenceStatus){ # check if same column has been assigned before in establishmentMeans
        dat$occurrenceStatus <- dat$establishmentMeans # if yes, duplicate column
      } else {
        colnames(dat)[col_names_import==col_occurrenceStatus] <- "occurrenceStatus"
      }
      all_column_names <- c(all_column_names,"occurrenceStatus")
      dat$occurrenceStatus <- tolower(dat$occurrenceStatus)
    }
    if (!is.na(FileInfo[i,"Column_degreeOfEstablishment"]) & FileInfo[i,"Column_degreeOfEstablishment"]!=""){
      col_degreeOfEstablishment <- FileInfo[i,"Column_degreeOfEstablishment"]
      if (exists("col_establishmentMeans") && col_establishmentMeans==col_degreeOfEstablishment){ # check if same column has been assigned before in establishmentMeans
        dat$degreeOfEstablishment <- dat$establishmentMeans # if yes, duplicate column
      } else if (exists("col_occurrenceStatus") && col_occurrenceStatus==col_degreeOfEstablishment){
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

    ## Always retain the traceability ID even when a caller leaves the optional
    ## record-ID mapping blank.
    if ("linkID" %in% colnames(dat)) {
      all_column_names <- c(all_column_names, "linkID")
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

message("SInAS 1/5: preparing columns")
results <- PrepareDatasets(FileInfo=FileInfo)


StandardiseTerms <- function(FileInfo=NULL){

 inputfiles <- results
  
  ## translation tables
  translation_estabmeans <- read.xlsx(config_file("Translation_establishmentMeans.xlsx"),sheet=1)
  translation_occurrence <- read.xlsx(config_file("Translation_occurrenceStatus.xlsx"),sheet=1)
  translation_degrEstab <- read.xlsx(config_file("Translation_degreeOfEstablishment.xlsx"),sheet=1)
  translation_pathway <- read.xlsx(config_file("Translation_pathway.xlsx"),sheet=1)
  translation_habitat <- read.xlsx(config_file("Translation_habitat.xlsx"),sheet=1)

  ## A value containing both native and alien means that origin is uncertain.
  ## This occurs in multiple GRIIS country checklists and otherwise becomes a
  ## blank that the merge incorrectly defaults to introduced.
  if (!any(tolower(translation_estabmeans$origTerm) == "native|alien", na.rm = TRUE)) {
    translation_estabmeans <- rbind(
      translation_estabmeans,
      data.frame(origTerm = "native|alien", newTerm = "uncertain")
    )
  }

  term_key <- function(x, column) {
    x <- trimws(tolower(as.character(x)))
    x[is.na(x)] <- ""
    if (column != "habitat") return(x)
    vapply(strsplit(x, "\\s*[|;]\\s*"), function(parts) {
      parts <- sort(unique(parts[nzchar(parts)]))
      paste(parts, collapse = "|")
    }, character(1))
  }

  unresolved_term_rows <- function(raw, final, translation, column) {
    raw <- as.character(raw)
    raw[is.na(raw)] <- ""
    accepted <- unique(c(
      term_key(translation$origTerm, column),
      term_key(translation$newTerm, column)
    ))
    raw_key <- term_key(raw, column)
    unresolved <- nzchar(trimws(raw)) & !raw_key %in% accepted
    values <- sort(unique(raw[unresolved]))
    if (length(values) == 0) return(NULL)
    dplyr::bind_rows(lapply(values, function(value) {
      rows <- raw == value
      result <- sort(unique(as.character(final[rows])))
      result[is.na(result)] <- ""
      data.frame(
        column = column,
        original_value = value,
        affected_records = sum(rows),
        resulting_value = paste(result, collapse = "; "),
        stringsAsFactors = FALSE
      )
    }))
  }

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
    term_issues <- list()
    
    ## Darwin Core: establishmentMeans
    if (any(colnames(dat)=="establishmentMeans")){
      dat$establishmentMeans <- gsub("^\\s+|\\s+$", "",dat$establishmentMeans) # trim leading and trailing whitespace
      raw_estabmeans <- dat$establishmentMeans
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
      term_issues$establishmentMeans <- unresolved_term_rows(
        raw_estabmeans, dat$establishmentMeans,
        translation_estabmeans, "establishmentMeans"
      )
    }

    ## Darwin Core: occurrenceStatus
    if (any(colnames(dat)=="occurrenceStatus")){
      dat$occurrenceStatus <- gsub("^\\s+|\\s+$", "",dat$occurrenceStatus) # trim leading and trailing whitespace
      raw_occurrence <- dat$occurrenceStatus
      # identify matches of alternative terms...
      ind <- match(tolower(dat$occurrenceStatus),tolower(translation_occurrence$origTerm)) # identify matches
      unresolved_occurrenceStatus <- unique(dat$occurrenceStatus[is.na(ind)]) # store mis-matches
      resolved_occurrenceStatus <- unique(dat$occurrenceStatus[!is.na(ind)]) # store matches
      translated <- translation_occurrence$newTerm[ind]
      indNA <- is.na(translated)
      dat$occurrenceStatus[!indNA] <- translated[!indNA]  # replace strings
      # identify matches of Darwin Core
      dat$occurrenceStatus[dat$occurrenceStatus!="absent"] <- "present" # Assumption (!) that all species are present if not listed otherwise
      term_issues$occurrenceStatus <- unresolved_term_rows(
        raw_occurrence, dat$occurrenceStatus,
        translation_occurrence, "occurrenceStatus"
      )
    }
    
    ## Darwin Core: degreeOfEstablishment (not officially accepted by Darwin Core)
    if (any(colnames(dat)=="degreeOfEstablishment")){
      dat$degreeOfEstablishment <- gsub("^\\s+|\\s+$", "",dat$degreeOfEstablishment) # trim leading and trailing whitespace
      raw_degree <- dat$degreeOfEstablishment
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
      term_issues$degreeOfEstablishment <- unresolved_term_rows(
        raw_degree, dat$degreeOfEstablishment,
        translation_degrEstab, "degreeOfEstablishment"
      )
    }
    
    ## Darwin Core: pathway
    if (any(colnames(dat)=="pathway")){
      dat$pathway <- gsub("^\\s+|\\s+$", "",dat$pathway) # trim leading and trailing whitespace
      raw_pathway <- dat$pathway
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
      term_issues$pathway <- unresolved_term_rows(
        raw_pathway, dat$pathway,
        translation_pathway, "pathway"
      )
    }
    
    ## Darwin Core: habitat
    if (any(colnames(dat)=="habitat")){
      dat$habitat <- gsub("^\\s+|\\s+$", "",dat$habitat) # trim leading and trailing whitespace
      raw_habitat <- dat$habitat
      # identify matches of alternative terms...
      ind <- match(term_key(dat$habitat, "habitat"), term_key(translation_habitat$origTerm, "habitat")) # identify matches of translated terms
      unresolved_habitat <- unique(dat$habitat[is.na(ind)]) # store mis-matches
      resolved_habitat <- unique(dat$habitat[!is.na(ind)]) # store matches
      translated <- translation_habitat$newTerm[ind]
      indNA <- is.na(translated)
      dat$habitat[!indNA] <- translated[!indNA]  # replace strings
      # identify matches of Darwin Core
      ind <- match(term_key(dat$habitat, "habitat"), term_key(translation_habitat$newTerm, "habitat")) # identify matches with Darwin Core
      dat$habitat <- translation_habitat$newTerm[ind] # replace strings
      dat$habitat[is.na(ind)] <- "" # indicate mis-matches
      term_issues$habitat <- unresolved_term_rows(
        raw_habitat, dat$habitat,
        translation_habitat, "habitat"
      )
    }
    
    
    ## Output ###########################
    
    clean_datasets[[dataset_name]] <- dat
    unresolved_terms[[dataset_name]] <- dplyr::bind_rows(term_issues)
  }
  
  return(list(clean_datasets = clean_datasets, unresolved_terms = unresolved_terms))
}

StandardiseLocationNames <- function(FileInfo = NULL, step2_output = NULL){
  
  inputfiles <- step2_output$clean_datasets  # named list from StandardiseTerms()
  
  ## load location tables #################################################
  regions <- read.xlsx(config_file("AllLocations.xlsx"), sheet = 2, na.strings = "")
  regions <- regions[regions$ISO3 == iso3, , drop = FALSE]
  regions <- regions[, c("locationID", "location", "location_var")]
  regions$location_var <- tolower(regions$location_var)
  regions$location_lower <- tolower(regions$location)
  
  subregions <- read.xlsx(config_file("AllLocations.xlsx"), sheet = 3, na.strings = "")
  subregions <- subregions[subregions$ISO3 == iso3, , drop = FALSE]
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

ApplyLocationCorrections <- function(location_output) {
  corrections <- read_optional_table(input$location_corrections)
  if (is.null(corrections) || nrow(corrections) == 0) return(location_output)
  required <- c("location_orig", "location", "locationID")
  if (!all(required %in% names(corrections))) {
    stop(
      "Location corrections must contain: ",
      paste(required, collapse = ", ")
    )
  }

  translated <- list(location_output$translated_locations)
  for (dataset_name in names(location_output$clean_datasets)) {
    dat <- location_output$clean_datasets[[dataset_name]]
    available <- corrections
    if ("dataset" %in% names(available)) {
      available <- available[
        is.na(available$dataset) | available$dataset == "" |
          available$dataset == dataset_name,
        , drop = FALSE
      ]
    }
    for (j in seq_len(nrow(available))) {
      rows <- tolower(trimws(as.character(dat$location_orig))) ==
        tolower(trimws(as.character(available$location_orig[j])))
      if (!any(rows, na.rm = TRUE)) next
      if (!is.na(available$location[j]) && available$location[j] != "") {
        dat$location[rows] <- as.character(available$location[j])
      }
      if (!is.na(available$locationID[j]) && available$locationID[j] != "") {
        dat$locationID[rows] <- as.character(available$locationID[j])
      }
      translated[[length(translated) + 1]] <- data.frame(
        location = as.character(available$location[j]),
        location_orig = as.character(available$location_orig[j]),
        origDB = dataset_name,
        locationID = as.character(available$locationID[j]),
        stringsAsFactors = FALSE
      )
    }
    location_output$clean_datasets[[dataset_name]] <- dat
    missing <- dat$location_orig[
      is.na(dat$locationID) | trimws(as.character(dat$locationID)) == ""
    ]
    if (length(missing) == 0) {
      location_output$missing_locations[[dataset_name]] <- NULL
    } else {
      location_output$missing_locations[[dataset_name]] <- sort(unique(missing))
    }
  }
  translated <- lapply(translated, function(dat) {
    if (!is.null(dat) && "locationID" %in% names(dat)) {
      dat$locationID <- as.character(dat$locationID)
    }
    dat
  })
  location_output$translated_locations <- unique(dplyr::bind_rows(translated))
  location_output
}

ApplyLocationFallbacks <- function(location_output) {
  ## This pipeline handles one country at a time. When a source location cannot
  ## be matched more precisely, retain the record at the selected country level
  ## and flag the fallback instead of dropping it during the merge.
  location_output$clean_datasets <- lapply(
    location_output$clean_datasets,
    function(dat) {
      ## First Records inputs commonly lack an ISO column; add explicit country
      ## provenance so canonical location aliases are still validated correctly.
      if (!"ISO3" %in% names(dat)) dat$ISO3 <- iso3
      dat
    }
  )
  regions <- read.xlsx(config_file("AllLocations.xlsx"), sheet = 2, na.strings = "")
  country_rows <- regions[regions$ISO3 == iso3, , drop = FALSE]
  exact <- country_rows[
    tolower(trimws(as.character(country_rows$location))) ==
      tolower(trimws(as.character(country_name))),
    , drop = FALSE
  ]
  if (nrow(exact) == 0 && "location_var" %in% names(country_rows)) {
    selected_name <- tolower(trimws(as.character(country_name)))
    alias_match <- vapply(
      as.character(country_rows$location_var),
      function(value) {
        if (is.na(value)) return(FALSE)
        selected_name %in% tolower(trimws(unlist(strsplit(value, ";"))))
      },
      logical(1)
    )
    exact <- country_rows[alias_match, , drop = FALSE]
  }
  if (nrow(exact) == 0 && nrow(country_rows) == 1) exact <- country_rows

  if (nrow(exact) != 1) {
    warning(
      "No unambiguous country-level location was found for ", country_name,
      " (", iso3, "). Unresolved locations remain in the warning report and ",
      "will be omitted from the merge."
    )
    return(location_output)
  }

  translations <- list(location_output$translated_locations)
  for (dataset_name in names(location_output$clean_datasets)) {
    dat <- location_output$clean_datasets[[dataset_name]]
    unresolved <- is.na(dat$locationID) |
      trimws(as.character(dat$locationID)) == ""
    if (!any(unresolved)) {
      location_output$clean_datasets[[dataset_name]] <- dat
      next
    }

    if (!"locationQCnote" %in% names(dat)) dat$locationQCnote <- NA_character_
    source_location <- as.character(dat$location_orig[unresolved])
    source_location[is.na(source_location) | !nzchar(trimws(source_location))] <-
      "<missing>"
    dat$location[unresolved] <- as.character(exact$location[[1]])
    dat$locationID[unresolved] <- as.character(exact$locationID[[1]])
    dat$locationQCnote[unresolved] <- paste0(
      "Unresolved source location '", source_location,
      "' assigned to selected country '", exact$location[[1]], "'"
    )
    location_output$clean_datasets[[dataset_name]] <- dat

    translations[[length(translations) + 1]] <- data.frame(
      location = as.character(exact$location[[1]]),
      location_orig = source_location,
      origDB = dataset_name,
      locationID = as.character(exact$locationID[[1]]),
      stringsAsFactors = FALSE
    )
  }
  translations <- lapply(translations, function(dat) {
    if (!is.null(dat) && "locationID" %in% names(dat)) {
      dat$locationID <- as.character(dat$locationID)
    }
    dat
  })
  combined_translations <- dplyr::bind_rows(translations)
  if (ncol(combined_translations) > 0) {
    location_output$translated_locations <- unique(combined_translations)
  }
  location_output
}

gbif_match_cache <- new.env(parent = emptyenv())

gbif_error_result <- function(error_message) {
  placeholder <- data.frame(
    canonicalName = NA_character_, scientificName = NA_character_,
    status = "GBIF_API_ERROR", matchType = "NONE", rank = NA_character_,
    confidence = NA_real_, usageKey = NA_real_, species = NA_character_,
    genus = NA_character_, family = NA_character_, class = NA_character_,
    order = NA_character_, phylum = NA_character_, kingdom = NA_character_,
    note = error_message, stringsAsFactors = FALSE
  )
  list(
    data = placeholder,
    alternatives = placeholder[0, , drop = FALSE],
    request_error = error_message
  )
}

safe_name_backbone_verbose <- function(name, strict = NULL) {
  strict_key <- if (is.null(strict)) "NULL" else as.character(strict)
  cache_key <- paste0(as.character(name), "||strict=", strict_key)
  if (exists(cache_key, envir = gbif_match_cache, inherits = FALSE)) {
    return(get(cache_key, envir = gbif_match_cache, inherits = FALSE))
  }

  attempts <- 3L
  last_error <- NULL
  for (attempt in seq_len(attempts)) {
    request_args <- list(
      name = name,
      curlopts = list(
        http_version = 2,
        connecttimeout_ms = 15000,
        timeout_ms = 45000
      )
    )
    if (!is.null(strict)) request_args$strict <- strict
    result <- tryCatch(
      do.call(rgbif::name_backbone_verbose, request_args),
      error = function(condition) condition
    )
    if (!inherits(result, "error")) {
      assign(cache_key, result, envir = gbif_match_cache)
      return(result)
    }

    last_error <- conditionMessage(result)
    if (attempt < attempts) {
      message(
        "GBIF request failed for '", name, "' (attempt ", attempt, "/",
        attempts, "): ", last_error, ". Retrying."
      )
      Sys.sleep(c(2, 5)[attempt])
    }
  }

  message(
    "GBIF request could not be completed for '", name,
    "' after ", attempts, " attempts. It will be reported as unmatched."
  )
  result <- gbif_error_result(last_error)
  assign(cache_key, result, envir = gbif_match_cache)
  result
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
    taxlist <- as.character(taxlist_lifeform$taxon)
    taxlist_kingdom <- as.character(taxlist_lifeform[[kingdom_user_col]])
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
  for (j in seq_len(n_taxa)){# loop over all species names; takes some hours...
    
    # select species name and download taxonomy
    if (!is.na(kingdom_user_col)) {
      ind_tax <- which(
        dat$taxon == taxlist[j] &
          tolower(as.character(dat[[kingdom_user_col]])) ==
            tolower(taxlist_kingdom[j])
      )
    } else {
      ind_tax <- which(dat$taxon==taxlist[j])
    }
    db_all <- safe_name_backbone_verbose(taxlist[j], strict = TRUE) # check for names and synonyms
    db <- db_all[["data"]]
    alternatives <- db_all$alternatives
    if (!is.null(db_all$request_error)) {
      dat$GBIFstatus[ind_tax] <- "GBIF_API_ERROR"
      dat$GBIFmatchtype[ind_tax] <- "NONE"
      dat$GBIFnote[ind_tax] <- db_all$request_error
    }
    
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
        
        db_all_2 <- safe_name_backbone_verbose(dat$taxon[ind_tax][1], strict = TRUE) # get scientific name
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
          accepted_exact <- alternatives[
            alternatives$status == "ACCEPTED" &
              alternatives$matchType == "EXACT",
            ,
            drop = FALSE
          ]
          selected <- accepted_exact[
            !is.na(accepted_exact$kingdom) &
              tolower(as.character(accepted_exact$kingdom)) ==
                tolower(taxlist_kingdom[j]),
            ,
            drop = FALSE
          ]

          if (nrow(selected) == 0) {
            warning(
              "No GBIF homonym candidate for '", taxlist[j],
              "' matched the supplied kingdom '", taxlist_kingdom[j], "'."
            )
            mismatches <- rbind(
              mismatches,
              data.frame(
                taxon = taxlist[j],
                status = "AMBIGUOUS",
                matchType = "KINGDOM_MISMATCH"
              )
            )
            next
          }
          if (length(unique(selected$family)) > 1) {
            warning(
              taxlist[j],
              " occurs in more than one GBIF family within kingdom ",
              taxlist_kingdom[j],
              ". Add author information to resolve it."
            )
          }

          selected <- selected[1, , drop = FALSE]
          dat$taxon[ind_tax] <- if (
            "canonicalName" %in% names(selected) &&
              !is.na(selected$canonicalName[1])
          ) selected$canonicalName[1] else selected$species[1]
          dat$scientificName[ind_tax] <- selected$scientificName[1]
          dat$GBIFstatus[ind_tax] <- selected$status[1]
          dat$GBIFmatchtype[ind_tax] <- selected$matchType[1]
          dat$GBIFtaxonRank[ind_tax] <- selected$rank[1]
          dat$GBIFusageKey[ind_tax] <- selected$usageKey[1]

          for (column in c(
            "species", "genus", "family", "class", "order", "phylum", "kingdom"
          )) {
            if (column %in% names(selected)) {
              dat[[column]][ind_tax] <- selected[[column]][1]
            }
          }

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
      db_all_2 <- safe_name_backbone_verbose(dat$taxon[ind_tax][1])
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
  uni_taxa$taxonID <- seq_len(nrow(uni_taxa))

  ## merge taxonID with full taxa list
  fullspeclist_2 <- merge(fullspeclist, uni_taxa, by = "scientificName", all = TRUE)
  missing_taxon_id <- which(is.na(fullspeclist_2$taxonID))
  if (length(missing_taxon_id) > 0) {
    available_taxon_ids <- fullspeclist_2$taxonID[
      !is.na(fullspeclist_2$taxonID)
    ]
    max_taxon_id <- if (length(available_taxon_ids) == 0) 0 else
      max(available_taxon_ids)
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
  replacements <- read.xlsx(config_file("Guidelines_eventDates.xlsx"))
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

read_taxon_corrections <- function(path) {
  if (is.null(path) || length(path) == 0) {
    return(NULL)
  }
  path <- as.character(path[[1]])
  if (is.na(path) || !file.exists(path)) return(NULL)
  if (grepl("[.]csv$", path, ignore.case = TRUE)) {
    out <- read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  } else {
    out <- read.xlsx(path, na.strings = "")
  }
  out[] <- lapply(out, as.character)
  out$correction_source <- rep(basename(path), nrow(out))
  out
}

LoadTaxonCorrections <- function() {
  resolution_directories <- c(
    "/scripts/IAS/P3_SInASworkflow/QualityControl/Outputs/ResolvedHarmonisations",
    "scripts/IAS/P3_SInASworkflow/QualityControl/Outputs/ResolvedHarmonisations"
  )
  resolution_directories <- resolution_directories[
    dir.exists(resolution_directories)
  ]

  reviewed <- NULL
  country_reviewed <- NULL
  if (length(resolution_directories) > 0) {
    resolution_directory <- resolution_directories[[1]]
    files <- list.files(
      resolution_directory, pattern = "[.]xlsx$", full.names = TRUE
    )
    reviewed <- dplyr::bind_rows(lapply(files, read_taxon_corrections))
    country_path <- file.path(resolution_directory, paste0(iso3, ".xlsx"))
    country_reviewed <- read_taxon_corrections(country_path)
  }

  ## Reuse a correction from another country only when all prior reviews agree
  ## on both the canonical and scientific names.
  reusable <- NULL
  if (!is.null(reviewed) && nrow(reviewed) > 0 &&
      "taxon_orig" %in% names(reviewed)) {
    reviewed <- reviewed[
      !is.na(reviewed$taxon_orig) & reviewed$taxon_orig != "", , drop = FALSE
    ]
    reviewed$correction_signature <- paste(
      ifelse(is.na(reviewed$New_taxon), "", reviewed$New_taxon),
      ifelse(is.na(reviewed$New_scientificName), "", reviewed$New_scientificName),
      sep = "||"
    )
    reusable <- reviewed |>
      dplyr::group_by(taxon_orig) |>
      dplyr::filter(dplyr::n_distinct(correction_signature) == 1) |>
      dplyr::slice(1) |>
      dplyr::ungroup() |>
      dplyr::select(-correction_signature)
  }

  packaged <- read_taxon_corrections(
    config_file("UserDefinedTaxonNames.xlsx")
  )
  ## Later tables have higher priority: the selected country's reviewed file,
  ## then packaged and unambiguous cross-country corrections.
  corrections <- dplyr::bind_rows(
    reusable, packaged, country_reviewed
  )
  if (nrow(corrections) == 0 || !"taxon_orig" %in% names(corrections)) {
    return(NULL)
  }
  corrections <- corrections[
    !is.na(corrections$taxon_orig) & corrections$taxon_orig != "",
    ,
    drop = FALSE
  ]
  corrections <- corrections[
    !duplicated(corrections$taxon_orig, fromLast = TRUE), , drop = FALSE
  ]
  corrections
}

ApplyTaxonCorrections <- function(taxon_output) {
  corrections <- LoadTaxonCorrections()
  if (is.null(corrections) || nrow(corrections) == 0) return(taxon_output)

  correction_map <- c(
    taxon = "New_taxon",
    scientificName = "New_scientificName",
    species = "species",
    genus = "genus",
    family = "family",
    order = "order",
    class = "class",
    phylum = "phylum",
    kingdom = "kingdom",
    GBIFstatus = "GBIFstatus",
    GBIFstatus_Synonym = "GBIFstatus_Synonym",
    GBIFmatchtype = "GBIFmatchtype",
    GBIFtaxonRank = "GBIFtaxonRank",
    GBIFusageKey = "GBIFusageKey",
    GBIFnote = "GBIFnote"
  )

  apply_to_table <- function(dat) {
    if (is.null(dat) || nrow(dat) == 0 || !"taxon_orig" %in% names(dat)) {
      return(dat)
    }
    for (i in seq_len(nrow(corrections))) {
      rows <- dat$taxon_orig == corrections$taxon_orig[i]
      if (!any(rows, na.rm = TRUE)) next
      for (target in names(correction_map)) {
        source <- correction_map[[target]]
        if (!source %in% names(corrections)) next
        value <- corrections[[source]][i]
        if (is.na(value) || trimws(as.character(value)) == "") next
        if (!target %in% names(dat)) dat[[target]] <- NA_character_
        dat[[target]][rows] <- as.character(value)
      }
    }
    dat
  }

  taxon_output$clean_datasets <- lapply(
    taxon_output$clean_datasets, apply_to_table
  )
  taxon_output$full_taxa_list <- apply_to_table(taxon_output$full_taxa_list)
  taxon_output$applied_corrections <- corrections
  taxon_output
}

BuildTaxonQualityControl <- function(taxon_output) {
  full <- taxon_output$full_taxa_list
  if (is.null(full) || nrow(full) == 0 || !"scientificName" %in% names(full)) {
    taxon_output$missing_taxa <- list()
    return(taxon_output)
  }

  unresolved <- is.na(full$scientificName) |
    trimws(as.character(full$scientificName)) == ""
  lookup_columns <- intersect(
    c("taxon_orig", "GBIFstatus", "GBIFstatus_Synonym", "GBIFmatchtype",
      "GBIFtaxonRank", "GBIFusageKey", "GBIFnote"),
    names(full)
  )
  lookup <- unique(full[unresolved, lookup_columns, drop = FALSE]) |>
    dplyr::group_by(taxon_orig) |>
    dplyr::slice(1) |>
    dplyr::ungroup()

  taxon_output$missing_taxa <- lapply(
    taxon_output$clean_datasets,
    function(dat) {
      bad <- is.na(dat$scientificName) |
        trimws(as.character(dat$scientificName)) == ""
      if (!any(bad)) return(NULL)
      record_columns <- intersect(
        c("linkID", "taxon_orig", "taxon", "taxonID", "scientificName"),
        names(dat)
      )
      out <- dat[bad, record_columns, drop = FALSE]
      dplyr::left_join(out, lookup, by = "taxon_orig") |>
        dplyr::distinct()
    }
  )
  taxon_output
}

ApplyTaxonFallbacks <- function(taxon_output) {
  ## Keep the source name when GBIF and reviewed corrections cannot resolve it.
  ## BuildTaxonQualityControl() runs first so these records remain in the
  ## warning report and correction template.
  apply_to_table <- function(dat) {
    if (is.null(dat) || nrow(dat) == 0 ||
        !all(c("taxon_orig", "scientificName") %in% names(dat))) {
      return(dat)
    }
    unresolved <- is.na(dat$scientificName) |
      trimws(as.character(dat$scientificName)) == ""
    if (!any(unresolved)) return(dat)
    if (!"taxon" %in% names(dat)) dat$taxon <- NA_character_
    if (!"taxonQCnote" %in% names(dat)) dat$taxonQCnote <- NA_character_
    empty_taxon <- unresolved & (
      is.na(dat$taxon) | trimws(as.character(dat$taxon)) == ""
    )
    dat$taxon[empty_taxon] <- as.character(dat$taxon_orig[empty_taxon])
    dat$scientificName[unresolved] <- as.character(dat$taxon_orig[unresolved])
    dat$taxonQCnote[unresolved] <-
      "No GBIF or reviewed match; original taxon name retained"
    dat
  }

  taxon_output$clean_datasets <- lapply(
    taxon_output$clean_datasets, apply_to_table
  )
  taxon_output$full_taxa_list <- apply_to_table(taxon_output$full_taxa_list)
  taxon_output
}

list_report <- function(items, value_name) {
  rows <- lapply(names(items), function(dataset_name) {
    item <- items[[dataset_name]]
    if (is.null(item) || length(item) == 0) return(NULL)
    if (is.data.frame(item)) {
      item$dataset <- dataset_name
      return(item)
    }
    data.frame(
      dataset = rep(dataset_name, length(item)),
      value = as.character(item),
      stringsAsFactors = FALSE
    )
  })
  out <- dplyr::bind_rows(rows)
  if ("value" %in% names(out)) names(out)[names(out) == "value"] <- value_name
  if (nrow(out) == 0) {
    out <- data.frame(dataset = character(), stringsAsFactors = FALSE)
    out[[value_name]] <- character()
  }
  out
}

message("SInAS 2/5: standardising terminology")
step2 <- StandardiseTerms(FileInfo = FileInfo)
message("SInAS 3/5: standardising locations")
step3 <- StandardiseLocationNames(FileInfo = FileInfo, step2_output = step2)
step3$clean_datasets <- lapply(step3$clean_datasets, function(dat) {
  ## First Records commonly lacks an ISO column. The run is country-scoped, so
  ## retain that provenance without treating an unmatched location as matched.
  if (!"ISO3" %in% names(dat)) dat$ISO3 <- iso3
  dat
})
message("SInAS 4/5: matching taxa against GBIF")
step4 <- StandardiseTaxonNames(FileInfo = FileInfo, step3_output = step3)
step4 <- ApplyTaxonCorrections(step4)
step4 <- BuildTaxonQualityControl(step4)
message("SInAS 5/5: standardising event dates")
step5 <- GeteventDate(FileInfo = FileInfo, step3_output = step4)

griis_clean <- step5$clean_datasets[["GRIIS"]]
first_records_clean <- step5$clean_datasets[["FirstRecords"]]

griis_path <- file.path(outputFolder, "GRIIS_clean.csv")
first_records_path <- file.path(outputFolder, "FirstRecords_clean.csv")
file_info_path <- file.path(outputFolder, "FileInfo.csv")
translated_locations_path <- file.path(outputFolder, "Translated_location_names.csv")
full_taxa_list_path <- file.path(
  outputFolder, paste0(iso3, "_SInAS_taxon_matching.csv")
)
translated_dates_path <- file.path(outputFolder, "Translated_event_dates.csv")
cleaning_summary_path <- file.path(outputFolder, "Cleaning_summary.csv")
qc_status_path <- file.path(outputFolder, "QC_status.csv")
unmatched_values_path <- file.path(outputFolder, "Unmatched_values.csv")
excluded_records_path <- file.path(
  outputFolder, paste0(iso3, "_SInAS_excluded_records.csv")
)

unresolved_terms <- list_report(step2$unresolved_terms, "term")
missing_locations <- list_report(step3$missing_locations, "location_orig")
missing_taxa <- list_report(step4$missing_taxa, "taxon")
nonnumeric_dates <- list_report(step5$nonnumeric_eventDates, "event_date")

translated_locations <- step3$translated_locations
if (is.null(translated_locations)) {
  translated_locations <- data.frame(
    location = character(), location_orig = character(),
    origDB = character(), locationID = character()
  )
}
translated_dates <- step5$translated_eventDates
if (is.null(translated_dates)) {
  translated_dates <- data.frame(
    eventDate = character(), eventDate2 = character(),
    eventDate_orig = character(), eventDate2_orig = character(),
    note = character(), origDB = character()
  )
}
full_taxa_list <- step4$full_taxa_list
if (is.null(full_taxa_list)) {
  full_taxa_list <- data.frame(taxon_orig = character())
}

## Consolidate all unmatched values into one report. These audit fields remain
## separate from the cleaned and merged datasets.
empty_unmatched <- data.frame(
  dataset = character(), check = character(), field = character(),
  original_value = character(), standardised_value = character(),
  affected_records = integer(), details = character(), action = character(),
  included_in_merge = character(), stringsAsFactors = FALSE
)

term_report <- NULL
if (nrow(unresolved_terms) > 0) {
  term_report <- data.frame(
    dataset = unresolved_terms$dataset,
    check = "terminology",
    field = unresolved_terms$column,
    original_value = unresolved_terms$original_value,
    standardised_value = ifelse(
      unresolved_terms$column == "establishmentMeans",
      "introduced",
      unresolved_terms$resulting_value
    ),
    affected_records = unresolved_terms$affected_records,
    details = "Not found in the packaged SInAS translation table",
    action = dplyr::case_when(
      unresolved_terms$column == "occurrenceStatus" ~
        "Set to present using the original SInAS assumption",
      unresolved_terms$column == "establishmentMeans" ~
        "Set to introduced during merge because the source is an alien-species database",
      TRUE ~ "Standardised value left missing"
    ),
    included_in_merge = "yes_if_location_matched",
    stringsAsFactors = FALSE
  )
}

location_report <- NULL
if (nrow(missing_locations) > 0) {
  location_report <- data.frame(
    dataset = missing_locations$dataset,
    check = "locations",
    field = "location",
    original_value = missing_locations$location_orig,
    standardised_value = "",
    affected_records = vapply(
      seq_len(nrow(missing_locations)),
      function(i) {
        dat <- step3$clean_datasets[[missing_locations$dataset[i]]]
        sum(
          as.character(dat$location_orig) ==
            as.character(missing_locations$location_orig[i]),
          na.rm = TRUE
        )
      },
      integer(1)
    ),
    details = "Not found in packaged country, subregion, or location-alias tables",
    action = "Record excluded from merge because locationID is missing",
    included_in_merge = "no",
    stringsAsFactors = FALSE
  )
}

taxon_report <- NULL
if (nrow(missing_taxa) > 0) {
  taxon_report_input <- missing_taxa
  detail_columns <- intersect(
    c(
      "GBIFstatus", "GBIFstatus_Synonym", "GBIFmatchtype",
      "GBIFtaxonRank", "GBIFnote"
    ),
    names(taxon_report_input)
  )
  if (length(detail_columns) == 0) {
    taxon_report_input$details <- "No reliable GBIF or packaged correction match"
  } else {
    taxon_report_input$details <- apply(
      taxon_report_input[, detail_columns, drop = FALSE],
      1,
      function(row) {
        row <- as.character(row)
        keep <- !is.na(row) & nzchar(trimws(row))
        if (!any(keep)) return("No reliable GBIF or packaged correction match")
        paste(paste0(detail_columns[keep], "=", row[keep]), collapse = "; ")
      }
    )
  }
  taxon_report <- taxon_report_input |>
    dplyr::mutate(
      original_value = as.character(taxon_orig),
      affected_records = 1L
    ) |>
    dplyr::group_by(dataset, original_value) |>
    dplyr::summarise(
      affected_records = dplyr::n(),
      details = paste(sort(unique(details)), collapse = "; "),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      check = "taxonomy",
      field = "scientificName",
      standardised_value = "",
      action = paste(
        "Original taxon retained in taxon; scientificName left missing"
      ),
      included_in_merge = "yes_if_location_matched"
    ) |>
    dplyr::select(
      dataset, check, field, original_value, standardised_value,
      affected_records, details, action, included_in_merge
    )
}

date_report <- NULL
if (nrow(nonnumeric_dates) > 0) {
  date_report <- data.frame(
    dataset = nonnumeric_dates$dataset,
    check = "event_dates",
    field = "eventDate",
    original_value = nonnumeric_dates$event_date,
    standardised_value = "",
    affected_records = 1L,
    details = "Not numeric after applying the packaged SInAS event-date guidelines",
    action = "Unconvertible date stored as missing",
    included_in_merge = "yes_if_location_matched",
    stringsAsFactors = FALSE
  )
}

unmatched_values <- dplyr::bind_rows(
  term_report, location_report, taxon_report, date_report
)
if (nrow(unmatched_values) == 0) unmatched_values <- empty_unmatched

excluded_records <- dplyr::bind_rows(lapply(
  names(step5$clean_datasets),
  function(dataset_name) {
    dat <- step5$clean_datasets[[dataset_name]]
    excluded <- is.na(dat$locationID) |
      trimws(as.character(dat$locationID)) == ""
    if (!any(excluded)) return(NULL)
    out <- dat[excluded, , drop = FALSE]
    out$dataset <- dataset_name
    out$exclusion_reason <- "Unmatched location; locationID is missing"
    out
  }
))
if (nrow(excluded_records) == 0) {
  excluded_records <- data.frame(
    dataset = character(), linkID = character(),
    exclusion_reason = character(), stringsAsFactors = FALSE
  )
}

issue_rows <- function(x) {
  if (is.null(x) || length(x) == 0) return(0L)
  if (is.data.frame(x)) return(nrow(x))
  length(x)
}

affected_term_records <- if (
  "affected_records" %in% names(unresolved_terms) && nrow(unresolved_terms) > 0
) sum(unresolved_terms$affected_records, na.rm = TRUE) else 0L

qc_checks <- data.frame(
  check = c("terminology", "locations", "taxonomy", "event_dates"),
  status = c(
    if (nrow(unresolved_terms) == 0) "PASS" else "WARNING",
    if (nrow(missing_locations) == 0) "PASS" else "WARNING",
    if (nrow(missing_taxa) == 0) "PASS" else "WARNING",
    if (nrow(nonnumeric_dates) == 0) "PASS" else "WARNING"
  ),
  issues = c(
    nrow(unresolved_terms), nrow(missing_locations),
    length(unique(missing_taxa$taxon_orig)), nrow(nonnumeric_dates)
  ),
  affected_records = c(
    affected_term_records, nrow(missing_locations),
    nrow(missing_taxa), nrow(nonnumeric_dates)
  ),
  action = c(
    if (nrow(unresolved_terms) == 0) "No action required" else
      "Unrecognised controlled terms left missing; occurrence status uses the SInAS present assumption",
    if (nrow(missing_locations) == 0) "No action required" else
      "Records with missing locationID excluded from merge and written to Excluded_records.csv",
    if (nrow(missing_taxa) == 0) "No action required" else
      "Original taxon retained; scientificName left missing",
    if (nrow(nonnumeric_dates) == 0) "No action required" else
      "Unconvertible date stored as missing"
  ),
  stringsAsFactors = FALSE
)
overall_status <- if (all(qc_checks$status == "PASS")) "PASS" else "WARNING"
qc_status <- rbind(
  data.frame(
    check = "overall", status = overall_status,
    issues = sum(qc_checks$issues),
    affected_records = sum(qc_checks$affected_records),
    action = if (overall_status == "PASS") "No action required" else
      "Merge may continue; review Unmatched_values.csv and Excluded_records.csv",
    stringsAsFactors = FALSE
  ),
  qc_checks
)

if (overall_status == "WARNING") {
  warning_checks <- qc_checks$check[qc_checks$status == "WARNING"]
  warning(
    "Quality control completed with warnings for: ",
    paste(warning_checks, collapse = ", "),
    ". See QC_status.csv, Unmatched_values.csv, and Excluded_records.csv."
  )
}

cleaning_summary <- data.frame(
  country = country_name,
  ISO3 = iso3,
  dataset = c("GRIIS", "FirstRecords"),
  input_records = c(nrow(GRIIS), nrow(FirstRecords_COUNTRY)),
  clean_records = c(nrow(griis_clean), nrow(first_records_clean)),
  unresolved_terms = c(
    issue_rows(step2$unresolved_terms$GRIIS),
    issue_rows(step2$unresolved_terms$FirstRecords)
  ),
  unresolved_locations = c(
    length(step3$missing_locations$GRIIS),
    length(step3$missing_locations$FirstRecords)
  ),
  unresolved_taxa = c(
    issue_rows(step4$missing_taxa$GRIIS),
    issue_rows(step4$missing_taxa$FirstRecords)
  ),
  excluded_from_merge = c(
    sum(excluded_records$dataset == "GRIIS"),
    sum(excluded_records$dataset == "FirstRecords")
  ),
  QC_status = overall_status,
  stringsAsFactors = FALSE
)

write.csv(griis_clean, griis_path, row.names = FALSE, na = "")
write.csv(first_records_clean, first_records_path, row.names = FALSE, na = "")
write.csv(FileInfo, file_info_path, row.names = FALSE, na = "")
write.csv(translated_locations, translated_locations_path, row.names = FALSE, na = "")
write.csv(full_taxa_list, full_taxa_list_path, row.names = FALSE, na = "")
write.csv(translated_dates, translated_dates_path, row.names = FALSE, na = "")
write.csv(cleaning_summary, cleaning_summary_path, row.names = FALSE, na = "")
write.csv(qc_status, qc_status_path, row.names = FALSE, na = "")
write.csv(unmatched_values, unmatched_values_path, row.names = FALSE, na = "")
write.csv(excluded_records, excluded_records_path, row.names = FALSE, na = "")

biab_output("griis_clean", griis_path)
biab_output("first_records_clean", first_records_path)
biab_output("file_info", file_info_path)
biab_output("translated_locations", translated_locations_path)
biab_output("full_taxa_list", full_taxa_list_path)
biab_output("translated_event_dates", translated_dates_path)
biab_output("cleaning_summary", cleaning_summary_path)
biab_output("qc_status", qc_status_path)
biab_output("unmatched_values", unmatched_values_path)
biab_output("excluded_records", excluded_records_path)
