## ------------------------------------------------------
## Script name: Prepare data for SInAS workflow
##
## Purpose of script: This script prepares the data for input into the SInAS workflow
##
## Author: Saxbee Affleck
##
## Date Created: 2025-08-27
## ------------------------------------------------------
## ------------------------------------------------------

## NOTE: This script should be run from the runWorkflow.R script in the SInAS workflow

## ------------------------------------------------------
## SELECT COUNTRY FOR TESTING
## ------------------------------------------------------ 

if(Country != "ALLDATA") {
  
  # Get all First Records Location IDs for country 
  locationIDs <- FirstRecordsLocations %>% dplyr::filter(ISO3 == Country) %>% dplyr::pull(locationID)
  
  GRIIS_COUNTRY <- GRIIS %>% 
    dplyr::filter(ISO3 == Country) %>% 
    tibble::rowid_to_column(var = "ID") %>% 
    dplyr::mutate(linkID = paste0(Country,"_G",ID)) %>% 
    dplyr::relocate(linkID, .before = ID) %>% 
    dplyr::select(-ID)
  
  FirstRecords_COUNTRY <- FirstRecords %>% 
    dplyr::filter(locationID %in% locationIDs) %>% 
    tibble::rowid_to_column(var = "ID") %>% 
    dplyr::mutate(linkID = paste0(Country,"_F",ID)) %>% 
    dplyr::relocate(linkID, .before = ID) %>% 
    dplyr::select(-ID)
  
  ########### UPDATE NOVEMBER 2025 ###############
  ## this update removes duplicated records from regions within a specific country (e.g. a first record from Tasmania vs mainland Australia)
  ## and ensures the earliest first record date is retained is there are multiple records, while overwriting the location name "Tasmania" with "Australia"
  ## to ensure the earlier date is the one retained in the following workflows. 
  
  if (any(duplicated(FirstRecords_COUNTRY$taxonID))) {
    
    ## remove duplicate records for single species within country for First Records database - keep earliest eventDate 
    FirstRecords_COUNTRY <- FirstRecords_COUNTRY %>% mutate(original_order = row_number())
    
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
    
  } else {FirstRecords_COUNTRY <- FirstRecords_COUNTRY}
  
  updateLocationNames <- FirstRecordsLocations %>% 
    dplyr::filter(ISO3 == Country) %>% 
    dplyr::select("gadm0_name") %>% 
    dplyr::slice_head(n = 1) %>% pull()
  FirstRecords_COUNTRY <- FirstRecords_COUNTRY %>% 
    dplyr::mutate(location = updateLocationNames)
  
  ########### END UPDATE ###############
  
  
  ########### UPDATE MARCH 2026 ###############
  ## This update is specifically for Norway, to address a data filtering error in the creation of the First Records database version 3.1  which was integrated as
  ## part of the SInAS database 3.0 which is used in this workflow. Basically, records taken from two papers - Sandvik et al. 2019 (https://doi.org/10.1007/s10530-019-02058-x) and 
  ## Sandvik et al. 2020 (https://doi.org/10.1002/2688-8319.12006) were integrated in the First Records database incorrectly. These two papers are the source of a substantial number
  ## of the first record dates for Norway, and this error was flagged with the creators of the First Records database, and corrected for an upcoming version 4.1(?) 
  ## (Hanno Seebens, personal communications). We are correcting it here to avoid erroneously including incorrect dates for the automated Norway modelling before 
  ## the corrected versions of the First Records database/SInAS database are publicly available
  
  
  if (Country == "NOR") {
    
    originalSandvik <- FirstRecords_COUNTRY %>% filter(grepl("FirstRecords", origDB), grepl("Sandvik", bibliographicCitation))
    
    correctedSandvik <- data.table::fread(file.path(workingDirectory,"01_InputData","FirstRecords_main_dataset_final_2026-03-09.csv")) %>%
      filter(location == "Norway", grepl("Sandvik", bibliographicCitation)) %>% mutate(Sandvik = "CORRECTED") %>%
      rename(eventDate = firstRecordEvent)
    
    ## CATEGORY ONE OF FIXES - TAXON WHERE BOTH ORIGINAL AND CORRECTED DATABASED LIST "SANDVIK" IN BIBLIOGRAPHICCITATION
    
    #filter taxon from original SInAS database with "Sandvik" in bibliographicCitation of both lists
    originalSandvik_inCorrected <- originalSandvik %>% filter(taxon %in% correctedSandvik$taxon)
    #filter taxon from new FirstRecords database with "Sandvik" in bibliographicCitation of both lists
    correctedSandvik_inOriginal <- correctedSandvik %>% filter(taxon %in% originalSandvik$taxon)
    #overwrite dates from original SInAS database with corrected "Sandvik" dates from new FirstRecords database
    duplicatedSandvik <- originalSandvik_inCorrected %>% rows_update(dplyr::select(correctedSandvik_inOriginal, taxon, eventDate), by = "taxon")
    ## 652 dates corrected
    
    
    ## CATEGORY TWO OF FIXES - TAXON WHERE ORIGINAL LISTS "SANDVIK" IN BIBLIOGRAPHICCITATION BUT CORRECTED DOES NOT - DATE LIKELY INCORRECT
    
    #filter species with "sandvik" in bibliographicCitation of original SInAS database, but not in new FirstRecords database
    # then set eventDate to NA as these dates from Sandvik are incorrect. Dates could be from other database if multiple bibliographicCitations
    # are included in original SInAS database, but no way to definitely know they are not incorrect dates from Sandvik. 
    originalSandvikLeftover <- originalSandvik %>% filter(!(taxon %in% duplicatedSandvik$taxon)) %>%
      mutate(eventDate = NA_real_)
    
    
    ## CATEGORY THREE OF FIXES - TAXON WHERE CORRECTED LISTS "SANDVIK" IN BIBLIOGRAPHICCITATION BUT ORIGINAL DOES NOT - EXISTING SPECIES NEED DATES COMPARED, NEW SPECIES SHOULD BE IGNORED
    
    #filter species with "sandvik" in bibliographicCitation of new FirstRecords database, but not in original SInAS database
    # For species present in original SInAS database, just without a Sandvik citation, compare Sandvik-sourced citation from 
    # new FirstRecords database to non-Sandvik sourced citation in original SInAS database and take earliest date
    # For species in new FirstRecords database that don't appear at all in original SInAS database, remove them from consideration. 
    
    #corrected NOT duplicated across lists with citation "Sandvik"
    correctedSandvikLeftoverExistingSpecies <- correctedSandvik %>% filter(!(taxon %in% duplicatedSandvik$taxon)) %>%
      #corrected YES present in original list (just without "sandvik" citation)
      filter(taxon %in% FirstRecords_COUNTRY$taxon) %>%
      dplyr::select(taxon, eventDate, bibliographicCitation)
    
    #pull those species from broader list, compare dates and take earliest 
    originalNotSandvikExistingSpecies <- FirstRecords_COUNTRY %>% 
      filter(taxon %in% correctedSandvikLeftoverExistingSpecies$taxon) %>%
      left_join(dplyr::select(correctedSandvikLeftoverExistingSpecies, taxon, eventDate, bibliographicCitation), by = "taxon") %>% 
      mutate(eventDate = case_when(eventDate.x < eventDate.y ~ eventDate.x, 
                                   TRUE ~ eventDate.y), 
             bibliographicCitation = case_when(eventDate.x < eventDate.y ~ bibliographicCitation.x, 
                                               TRUE ~ bibliographicCitation.y)) %>%
      dplyr::select(-c(eventDate.x, eventDate.y, bibliographicCitation.x, bibliographicCitation.y))
    
    ## MERGE THREE CATEGORIES TOGETHER 
    
    fixedNorwayRecords <- duplicatedSandvik %>% add_row(originalSandvikLeftover) %>% add_row(originalNotSandvikExistingSpecies)
    
    ## UPDATE EXISTING DATASET WITH CORRECTED RECORDS 
    
    FirstRecords_COUNTRY <- FirstRecords_COUNTRY %>% rows_update(fixedNorwayRecords, by = "taxon")
    
  }
  
  ########### END UPDATE ###############
  
} else {
  
  # Create test data set for Australia
  GRIIS_COUNTRY <- GRIIS %>% 
    #dplyr::filter(ISO3 == Country) %>% 
    tibble::rowid_to_column(var = "ID") %>% 
    dplyr::mutate(linkID = paste0(Country,"_G",ID)) %>% 
    dplyr::relocate(linkID, .before = ID) %>% 
    dplyr::select(-ID)
  
  FirstRecords_COUNTRY <- FirstRecords %>% 
    #dplyr::filter(locationID %in% locationIDs) %>% 
    tibble::rowid_to_column(var = "ID") %>% 
    dplyr::mutate(linkID = paste0(Country,"_F",ID)) %>% 
    dplyr::relocate(linkID, .before = ID) %>% 
    dplyr::select(-ID)
  
}


## ------------------------------------------------------
## SAVE DATASETS TO INPUT FOLDER
## ------------------------------------------------------ 

# Save filtered GRIIS data
# openxlsx::write.xlsx(GRIIS, file.path(workingDirectory,subDirectory,"Inputfiles","GRIIS.xlsx"))
# openxlsx::write.xlsx(GRIIS_uniqueSpecies, file.path(workingDirectory,subDirectory,"Inputfiles","GRIIS_uniqueSpecies.xlsx"))
openxlsx::write.xlsx(GRIIS_COUNTRY, file.path(workingDirectory,subDirectory,"Inputfiles",paste0("GRIIS_",Country,".xlsx")))

# Save filtered First Records data
# openxlsx::write.xlsx(FirstRecords, file.path(workingDirectory,subDirectory,"Inputfiles","FirstRecords.xlsx"))
# openxlsx::write.xlsx(FirstRecords_uniqueSpecies, file.path(workingDirectory,subDirectory,"Inputfiles","FirstRecords_uniqueSpecies.xlsx"))
openxlsx::write.xlsx(FirstRecords_COUNTRY, file.path(workingDirectory,subDirectory,"Inputfiles",paste0("FirstRecords_",Country,".xlsx")))


## ------------------------------------------------------
## CONFIGURE VARIABLE NAMES
## ------------------------------------------------------ 

Variables <- readxl::read_xlsx(file.path(config_dir, "DatabaseInfo.xlsx"), sheet = 1)
Variables <- Variables[0,] # Removes all rows

# Specify which columns in each data frame provide species, location and event date information
Variables <- Variables %>% 
  dplyr::bind_rows(., tibble(Dataset_brief_name = c("GRIIS","FirstRecords"))) %>% 
  dplyr::mutate(File_name_to_load = 
                  dplyr::case_when(
                    Dataset_brief_name == "GRIIS" ~ paste0("GRIIS_",Country,".xlsx"),  
                    Dataset_brief_name == "FirstRecords" ~ paste0("FirstRecords_",Country,".xlsx"))) %>%
  dplyr::mutate(Column_taxon = 
                  dplyr::case_when(
                    Dataset_brief_name == "GRIIS" ~ "scientificName",
                    Dataset_brief_name == "FirstRecords" ~ "taxon")) %>%
  dplyr::mutate(Column_location = 
                  dplyr::case_when(
                    Dataset_brief_name == "GRIIS" ~ "checklistName",
                    Dataset_brief_name == "FirstRecords" ~ "location")) %>%
  dplyr::mutate(Column_eventDate1 = 
                  dplyr::case_when(
                    Dataset_brief_name == "FirstRecords" ~ "eventDate")) %>% 
  dplyr::mutate(Column_bibliographicCitation = 
                  dplyr::case_when(
                    Dataset_brief_name == "FirstRecords" ~ "bibliographicCitation")) %>% 
  dplyr::mutate(Taxon_group = "All") %>% 
  dplyr::mutate(Column_kingdom = 
                  dplyr::case_when(
                    Dataset_brief_name == "GRIIS" ~ "kingdom",
                    Dataset_brief_name == "FirstRecords" ~ "kingdom")) %>% 
  dplyr::mutate(Column_country_ISO = 
                  dplyr::case_when(
                    Dataset_brief_name == "GRIIS" ~ "ISO3")) %>% 
  dplyr::mutate(Column_habitat = 
                  dplyr::case_when(
                    Dataset_brief_name == "GRIIS" ~ "habitat",
                    Dataset_brief_name == "FirstRecords" ~ "habitat")) %>% 
  dplyr::mutate(Column_additional = 
                  dplyr::case_when(
                    Dataset_brief_name == "GRIIS" ~ "linkID; isInvasive; isInvasiveInCountry; isInvasiveAnywhere; kingdom", # Must have space after semicolon
                    Dataset_brief_name == "FirstRecords" ~ "linkID"))

View(Variables)
# write DatabaseInfo into the BIAB output Config so it is captured
out_config_dir <- file.path(workingDirectory, "Config")
if (!dir.exists(out_config_dir)) dir.create(out_config_dir, recursive = TRUE)
writexl::write_xlsx(Variables, file.path(out_config_dir, "DatabaseInfo.xlsx"))
