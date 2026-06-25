library(tidyRSS)
library(dplyr)
library(tidyr)
library(rvest)
library(stringr)
library(XML)
library(readxl)

input <- biab_inputs()

country_name <- input$country_name$country$englishName
## need to inlcude a check so that it fails if the country is not in the compendium

iso3 <- input$country_name$country$ISO3
print(iso3)
if (is.null(iso3) || is.na(iso3) || iso3 == "") {
stop(paste0("ISO3 is missing for selected country: ", country_name))
}
print(country_name)
print(class(country_name))
compendium_countries <- read_excel(input$compendium_countries)

feed_url <- "https://cloud.gbif.org/griis/rss.do"

feed <- tidyRSS::tidyfeed(feed_url)

# Extract information from each link for country and version
feed <-
  feed %>%
  tidyr::separate(
    item_title,
    c("item_type", "version"),
    sep = " - Version",
    remove = FALSE
  ) %>%
  dplyr::mutate(item_type = sub("Protected Areas -", "PA ", item_type)) %>%
  dplyr::mutate(item_type = sub(" – ", "=", item_type)) %>%
  dplyr::mutate(item_type = sub("-", "=", item_type)) %>%
  tidyr::separate(
    item_type,
    c("item_type", "country"),
    sep = "=",
    remove = FALSE
  ) %>%
  dplyr::mutate(
    item_type = dplyr::case_when(
      stringr::str_detect(item_type, "PA ") ~ "protectedArea",
      TRUE ~ "national"
    ),
    country = trimws(country)
  )

# Match requested country
feed_match <- feed %>%
  dplyr::filter(
    country == country_name |
      stringr::str_ends(
        stringr::str_squish(country),
        paste0(", ", country_name)
      )
  )
print("feed match")
print(feed_match)

checklist_list <- vector("list", nrow(feed_match))
summary_list <- vector("list", nrow(feed_match))
directory_list <- vector("list", nrow(feed_match))

if (nrow(feed_match) == 0) {
  stop(sprintf("No GRIIS checklists found for %s.", country_name))
}

for (i in seq_len(nrow(feed_match))) {

  checklist_name <- feed_match$country[[i]]
  checklist_type <- feed_match$item_type[[i]]
  version <- stringr::str_trim(feed_match$version[[i]])

# Get details of checklist
name <- feed_match[i, ] %>% dplyr::pull(country)
name <- stringr::str_trim(name, side = c("both"))
checklist_level <- ifelse(stringr::str_detect(name, ","), "Secondary", "Primary")
name <- gsub("[^[:alnum:]]", "_", name)

type <- feed_match[i, ] %>% dplyr::pull(item_type)

version <- feed_match[i, ] %>% dplyr::pull(version)
version <- stringr::str_trim(version, side = c("both"))

# Get country-specific page content and search for download link to zip file
url <- feed_match$item_link[[i]]
html <- rvest::read_html(url)
tables <-
  html |>
  rvest::html_elements("table") |>
  rvest::html_children()
url <- tables[[1]] |>
  rvest::html_element("a") |>
  rvest::html_attr(name = "href")

# Downloads with specified name into specified location - needs to be country name when looped + subfolders?
download.file(url,
  destfile = file.path(outputFolder, "temp.zip"),
  mode = "wb"
)
unzip(file.path(outputFolder, "temp.zip"), exdir = outputFolder)

species <- read.csv(file.path(outputFolder, "speciesprofile.txt"),
  sep = "\t",
  quote = ""
)
taxon <- read.csv(file.path(outputFolder, "taxon.txt"), sep = "\t", quote = "")
dist <- read.csv(file.path(outputFolder, "distribution.txt"), sep = "\t", quote = "")

# Download and extract relevant meta data
meta <- XML::xmlParse(file.path(outputFolder, "eml.xml"))
meta <- XML::xmlToList(meta)

alternativeIdentifier <- meta$dataset$alternateIdentifier
publicationDate <-
  trimws(gsub("\n", "", meta$dataset$pubDate), which = "both")

# bounding box of the country
northBoundingCoordinate <- meta$dataset$coverage$geographicCoverage$boundingCoordinates$northBoundingCoordinate
southBoundingCoordinate <- meta$dataset$coverage$geographicCoverage$boundingCoordinates$southBoundingCoordinate
eastBoundingCoordinate <- meta$dataset$coverage$geographicCoverage$boundingCoordinates$eastBoundingCoordinate
westBoundingCoordinate <- meta$dataset$coverage$geographicCoverage$boundingCoordinates$westBoundingCoordinate

# Remove temp file once complete
unlink(file.path(outputFolder, "temp.zip"))

# Unify the "distribution" text file to the other invasive status/species profile
join_1 <- species |>
  dplyr::left_join(taxon, by = c("id" = "id"))
griis_checklist <- join_1 %>%
  dplyr::left_join(dist, by = c("id" = "id")) %>%
  dplyr::mutate(
    fileName =  paste0(name, "_v", version, ".csv"),
    .before = 1
  )

checklist_list[[i]] <- griis_checklist
# Gather summary statistics for list
DATE <- Sys.Date()
summary_list[[i]] <- tidyr::tibble(
  downloadDate = DATE,
  name = gsub("_", " ", gsub("__", ", ", name)),
  ISO3 = iso3,
  countryInCompendium = ifelse(iso3 %in% compendium_countries$ISO3, TRUE, FALSE),
  checklistType = type,
  checklistLevel = checklist_level,
  version = version,
  speciesCount = nrow(griis_checklist),
  invasiveCount = griis_checklist %>% dplyr::filter(isInvasive == "Invasive") %>% nrow()
)


# Gather Data for file directory
directory_list[[i]] <- tidyr::tibble(
  fileName = paste0(name, "_v", version, ".csv"),
  downloadDate = DATE,
  name = gsub("_", " ", gsub("__", ", ", name)),
  ISO3 = iso3,
  countryInCompendium = ifelse(iso3 %in% compendium_countries$ISO3, TRUE, FALSE),
  checklistType = type,
  checklistLevel = checklist_level,
  version = version,
  northBoundingCoordinate = northBoundingCoordinate,
  southBoundingCoordinate = southBoundingCoordinate,
  eastBoundingCoordinate = eastBoundingCoordinate,
  westBoundingCoordinate = westBoundingCoordinate,
  alternativeIdentifier = alternativeIdentifier,
  url = url,
  publicationDate = publicationDate
)

}

griis_checklists <- dplyr::bind_rows(checklist_list)
summaries <- dplyr::bind_rows(summary_list)
directory <- dplyr::bind_rows(directory_list)


griis_checklist <- griis_checklists %>%
  dplyr::left_join(directory, by = c("fileName" = "fileName")) %>%
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
preClean_invasive_summary_allData <- griis_checklist %>% dplyr::group_by(isInvasive) %>% dplyr::count()
preClean_invasive_summary_natPA <- griis_checklist %>% dplyr::group_by(isInvasive,checklistType) %>% dplyr::count()

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
# Helper to join checklistType from directory table
add_checklist_type <- function(df) {
  df %>%
    dplyr::left_join(
      directory %>%
        dplyr::select("name", "checklistType") %>%
        dplyr::rename(checklistName = .data$name),
      by = "checklistName"
    ) %>%
    dplyr::relocate("checklistType", .after = "checklistName")
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
checklist_path <- file.path(outputFolder, "GRIIS_checklist.csv")
summary_path <- file.path(outputFolder, "GRIIS_summary.csv")
directory_path <- file.path(outputFolder, "GRIIS_directory.csv")

# Save checklist
write.csv(all_data_summary, allData_path, row.names = FALSE)
write.csv(per_list_summary, perList_path, row.names = FALSE)
write.csv(griis_checklist, checklist_path, row.names = FALSE)
write.csv(summaries, summary_path, row.names = FALSE)
write.csv(directory, directory_path, row.names = FALSE)
biab_output("all_data_summary", allData_path)
biab_output("per_list_summary", perList_path)
biab_output("griis_checklist", checklist_path)
biab_output("griis_summary", summary_path)
biab_output("griis_directory", directory_path)
