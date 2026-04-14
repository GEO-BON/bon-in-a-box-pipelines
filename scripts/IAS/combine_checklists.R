library(tidyverse)


input <- biab_inputs()

griis_checklist <- read.csv(input$griis_checklist)
file_directory <- read.csv(input$griis_directory)

griis_checklist <- griis_checklist %>%
cbind(file_directory)%>%
dplyr::rename(checklistName = name)

# Clean Habitat Variable
griis_checklist <- griis_checklist %>% dplyr::mutate(habitat = toupper(habitat))

UniqueHabitats <- griis_checklist %>% dplyr::mutate(habitat = gsub("/","|",habitat)) %>%
  dplyr::distinct(habitat) %>% dplyr::arrange() %>% 
  dplyr::mutate(habitat = dplyr::case_when(is.na(habitat) ~ "NODATA", TRUE ~ as.character(habitat))) %>%
  dplyr::mutate(terrestrial = dplyr::case_when(grepl(c("TERRESTRIAL|TRESTRIAL"), habitat) ~ "TERRESTRIAL ", TRUE ~ ""),
                marine = dplyr::case_when(grepl("MARINE", habitat) ~ "MARINE ", TRUE ~ ""),
                freshwater = dplyr::case_when(grepl(c("FRESHWATER|FRESHHWATER|FRESHWATETR|FRESHHWATER"), habitat) ~ "FRESHWATER ", TRUE ~ ""),
                brackish = dplyr::case_when(grepl("BRACKISH", habitat) ~ "BRACKISH ", TRUE ~ ""),
                host = dplyr::case_when(grepl("HOST", habitat) ~ "HOST ", TRUE ~ ""),
                nodata = dplyr::case_when(grepl("NODATA", habitat) ~ "NODATA ", TRUE ~ "")) %>% 
  dplyr::mutate(habitatStandardised = paste(terrestrial,marine,freshwater,brackish,host,nodata)) %>% 
  dplyr::mutate(habitatStandardised = stringr::str_trim(habitatStandardised, side = "both")) %>%
  dplyr::mutate(habitatStandardised = stringr::str_squish(habitatStandardised)) %>%
  dplyr::mutate(habitatStandardised = gsub(" ","|",habitatStandardised)) %>% 
  dplyr::select(habitat,habitatStandardised) %>% 
  dplyr::bind_rows(., tibble(habitat = c("TERRESTRIAL/FRESHWATER","FRESHWATER/BRACKISH","FRESHWATER/BRACKISH/MARINE"), 
                             habitatStandardised = c("TERRESTRIAL|FRESHWATER","FRESHWATER|BRACKISH","MARINE|FRESHWATER|BRACKISH")))

griis_checklist <- griis_checklist %>% dplyr::mutate(habitat = dplyr::case_when(is.na(habitat) ~ "NODATA", TRUE ~ as.character(habitat))) 

griis_checklist <- dplyr::left_join(griis_checklist,UniqueHabitats, by = "habitat") %>% dplyr::select(-habitat) %>% dplyr::rename(habitat = habitatStandardised)

# Clean kingdom variable
griis_checklist <- griis_checklist %>% dplyr::mutate(kingdom = toupper(kingdom)) %>% 
  dplyr::mutate(kingdom = dplyr::case_when(is.na(kingdom) ~ "NODATA", TRUE ~ as.character(kingdom)))

# Clean isInvasive variable
griis_checklist <- griis_checklist %>% dplyr::mutate(isInvasive = toupper(isInvasive))
griis_checklist <- griis_checklist %>% dplyr::mutate(isInvasive = toupper(isInvasive)) %>% 
  dplyr::mutate(isInvasive = dplyr::case_when(isInvasive %in% c("INVASIVE","YES","TRUE","INVASIVE IN THE NORTH OF THE ISLAND (122).") ~ "INVASIVE",
                                              is.na(isInvasive) ~ "NODATA",
                                              TRUE ~ "NULL")) 

# Create isInvasiveInCountry and isInvasiveAnywhere columns
# Skipping isInvasiveAnywhere for now as this requires checking each species across all checklists
#isInvasiveAnywhere <- griis_checklist %>% 
#  dplyr::filter(isInvasive == "INVASIVE") %>% 
#  dplyr::distinct(scientificName) %>% 
#  dplyr::pull(scientificName)

griis_checklist <- griis_checklist %>% 
  dplyr::mutate(isInvasiveInCountry = dplyr::case_when(
    isInvasive == "INVASIVE" ~ TRUE, 
    TRUE ~ as.logical(FALSE)))

## ------------------------------------------------------
## GENERATE AND SAVE SUMMARIES 
## ------------------------------------------------------

# Summary for all data
# Taxonomic breakdown
kingdom_summary_allData <- griis_checklist %>% dplyr::group_by(kingdom) %>% dplyr::count() 
kingdom_summary_natPA <- griis_checklist %>% dplyr::group_by(kingdom,checklistType) %>% dplyr::count() 

# Habitat breakdown 
habitat_summary_allData <- griis_checklist %>% dplyr::group_by(habitat) %>% dplyr::count() 
habitat_summary_natPA <-griis_checklist %>% dplyr::group_by(habitat,checklistType) %>% dplyr::count() 

# isInvasive breakdown 
invasive_summary_allData <- griis_checklist %>% dplyr::group_by(isInvasive) %>% dplyr::count() 
invasive_summary_natPA <- griis_checklist %>% dplyr::group_by(isInvasive,checklistType) %>% dplyr::count() 

preClean_invasive_summary_allData <- griis_checklist %>% dplyr::group_by(isInvasive) %>% dplyr::count() 
preClean_invasive_summary_natPA <- griis_checklist %>% dplyr::group_by(isInvasive,checklistType) %>% dplyr::count() 

# Combine all all-data summaries into one sheet using a "category" label column
all_data_summary <- dplyr::bind_rows(
  kingdom_summary_allData  %>% dplyr::mutate(category = "Kingdom",  breakdownBy = "All Data") %>% dplyr::rename(group = kingdom),
  kingdom_summary_natPA    %>% dplyr::mutate(category = "Kingdom",  breakdownBy = "By Type")  %>% dplyr::rename(group = kingdom),
  habitat_summary_allData  %>% dplyr::mutate(category = "Habitat",  breakdownBy = "All Data") %>% dplyr::rename(group = habitat),
  habitat_summary_natPA    %>% dplyr::mutate(category = "Habitat",  breakdownBy = "By Type")  %>% dplyr::rename(group = habitat),
  invasive_summary_allData %>% dplyr::mutate(category = "Invasive", breakdownBy = "All Data") %>% dplyr::rename(group = isInvasive),
  invasive_summary_natPA   %>% dplyr::mutate(category = "Invasive", breakdownBy = "By Type")  %>% dplyr::rename(group = isInvasive),
  preClean_invasive_summary_allData %>% dplyr::mutate(category = "Invasive_preCleaning", breakdownBy = "All Data") %>% dplyr::rename(group = isInvasive),
  preClean_invasive_summary_natPA   %>% dplyr::mutate(category = "Invasive_preCleaning", breakdownBy = "By Type")  %>% dplyr::rename(group = isInvasive)
) %>%
  dplyr::relocate(category, breakdownBy)

# Summary for individual checklists
# Taxonomic breakdown 
# Helper to join checklistType from file_directory
add_checklist_type <- function(df) {
  df %>%
    dplyr::left_join(
      file_directory %>% dplyr::select(name, checklistType) %>% dplyr::rename(checklistName = name),
      by = "checklistName"
    ) %>%
    dplyr::relocate(checklistType, .after = checklistName)
}

kingdom_summary_perList <- griis_checklist %>%
  dplyr::group_by(checklistName, kingdom) %>% dplyr::count() %>%
  tidyr::spread(key = kingdom, value = n) %>%
  add_checklist_type() %>%
  dplyr::mutate(category = "Kingdom")

habitat_summary_perList <- griis_checklist %>%
  dplyr::group_by(checklistName, habitat) %>% dplyr::count() %>%
  tidyr::spread(key = habitat, value = n) %>%
  add_checklist_type() %>%
  dplyr::mutate(category = "Habitat")

invasive_summary_perList <- griis_checklist %>%
  dplyr::group_by(checklistName, isInvasive) %>% dplyr::count() %>%
  tidyr::spread(key = isInvasive, value = n) %>%
  add_checklist_type() %>%
  dplyr::mutate(category = "Invasive")

# Combine all per-checklist summaries (bind_rows aligns shared cols, fills NAs for others)
per_list_summary <- dplyr::bind_rows(
  kingdom_summary_perList,
  habitat_summary_perList,
  invasive_summary_perList
) %>%
  dplyr::relocate(category)

# setting output paths
allData_path <- file.path(outputFolder, "allData_summary.csv")
perList_path <- file.path(outputFolder, "perList_summary.csv")

# Save checklist
write.csv(all_data_summary, allData_path, row.names = FALSE)
write.csv(per_list_summary, perList_path, row.names = FALSE)
biab_output("all_data_summary", allData_path)
biab_output("per_list_summary", perList_path)
