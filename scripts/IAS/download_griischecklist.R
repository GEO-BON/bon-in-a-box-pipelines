# This script downloads the GRIIS checklist for a specified country and attaches metadata. This currently combines the country with all affiliated regions (e.g., territories, overseas regions) to produce a single checklist for the country.

# load packages
library(tidyRSS)
library(dplyr)
library(tidyr)
library(rvest)
library(stringr)
library(XML)
library(readxl)
library(countrycode)

# load inputs
input <- biab_inputs()

country_name <- input$country_name$country$englishName
compendium_countries <- read_excel(input$compendium_countries)
iso3 <- input$country_name$country$ISO3

# input checks

# check if selected country is in the compendium
ifelse(!country_name %in% compendium_countries$country,
      biab_error_stop(paste0("The selected country is not in the compendium: ", country_name)),
      print(paste0("The selected country is in the compendium: ", country_name)))

# check if selected country has an ISO3 code
if (is.null(iso3) || is.na(iso3) || iso3 == "") {
  biab_error_stop(paste0("ISO3 is missing for selected country: ", country_name))
}

# Link to GRIIS data
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
    country = stringr::str_squish(country)
  )

# Match requested country
feed_match <- feed %>%
  dplyr::filter(
    item_type == "national",
    country == country_name |
      stringr::str_ends(stringr::str_squish(country), paste0(", ", country_name)) |
      (iso3 == "USA" & country == "United States of America, Contiguous") |
      (iso3 == "SWZ" & country == "Eswatini, Swaziland") |
      (iso3 == "PRK" & country == "Korea, Democratic People's Republic of")
  )

# The RSS feed can contain more than one release of a checklist. Convert each
# dotted version to a zero-padded key so that, for example, 1.10 sorts after 1.9.
version_key <- function(version) {
  parts <- stringr::str_extract_all(as.character(version), "[0-9]+")[[1]]
  if (length(parts) == 0) return("")
  paste(sprintf("%08d", as.integer(parts)), collapse = ".")
}

feed_match <- feed_match %>%
  dplyr::mutate(
    version = stringr::str_trim(version),
    versionKey = vapply(version, version_key, character(1))
  ) %>%
  dplyr::group_by(country, item_type) %>%
  dplyr::filter(versionKey == max(versionKey)) %>%
  dplyr::slice_head(n = 1) %>%
  dplyr::ungroup() %>%
  dplyr::select(-versionKey)
print("feed match")
print(feed_match)

checklist_list <- vector("list", nrow(feed_match))
summary_list <- vector("list", nrow(feed_match))
directory_list <- vector("list", nrow(feed_match))

if (nrow(feed_match) == 0) {
  stop(sprintf("No national GRIIS checklists found for %s.", country_name))
}

# These primary national checklist titles contain commas and were manually
# corrected in the original P1 workflow. All other comma-separated national
# titles represent secondary/affiliated checklists.
primary_checklist_names <- c(
  "United States of America, Contiguous",
  "Eswatini, Swaziland",
  "Korea, Democratic People's Republic of"
)

# Matches retained from the original P1 ISO3 corrections. countrycode handles
# the remaining checklist names directly.
custom_iso3 <- c(
  "Rapa Nui, Isla de Pascua, Easter Island" = "CHL",
  "Curacao, Netherlands" = "CUW",
  "French Southern and Antarctic Lands Terres australes et antarctiques françaises, TAAF, France" = "ATF",
  "French Southern and Antarctic Territories, TAAF, Scattered Islands, Îles Éparses, France" = "ATF",
  "Mayotte, France" = "MYT",
  "New Caledonia, France" = "NCL",
  "Pitcairn Islands, Great Britain" = "PCN",
  "Sint Maarten, Netherlands" = "SXM",
  "Svalbard, Norway" = "SJM",
  "Jeju Island, Republic of Korea" = "KOR",
  "United States of America, Contiguous" = "USA",
  "Eswatini, Swaziland" = "SWZ",
  "Korea, Democratic People's Republic of" = "PRK"
)

for (i in seq_len(nrow(feed_match))) {

  checklist_name <- feed_match$country[[i]]
  checklist_type <- feed_match$item_type[[i]]
  version <- stringr::str_trim(feed_match$version[[i]])

# Get details of checklist
name <- feed_match[i, ] %>% dplyr::pull(country)
name <- stringr::str_squish(name)
checklist_iso3 <- countrycode::countrycode(
  name,
  origin = "country.name",
  destination = "iso3c",
  custom_match = custom_iso3,
  warn = FALSE
)
if (is.na(checklist_iso3)) {
  biab_error_stop(paste0("Could not assign an ISO3 code to GRIIS checklist: ", name))
}
checklist_level <- ifelse(
  !stringr::str_detect(name, ",") || name %in% primary_checklist_names,
  "Primary",
  "Secondary"
)
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
  ISO3 = checklist_iso3,
  countryInCompendium = checklist_iso3 %in% compendium_countries$ISO3,
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
  ISO3 = checklist_iso3,
  countryInCompendium = checklist_iso3 %in% compendium_countries$ISO3,
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

# Habitat breakdown 
habitat_summary_allData <- griis_checklist %>% dplyr::group_by(habitat) %>% dplyr::count() 

# isInvasive breakdown 
invasive_summary_allData <- griis_checklist %>% dplyr::group_by(isInvasive) %>% dplyr::count() 

# Combine all all-data summaries into one sheet using a "category" label column
all_data_summary <- dplyr::bind_rows(
  kingdom_summary_allData  %>% dplyr::mutate(category = "Kingdom",  breakdownBy = "All Data") %>% dplyr::rename(group = kingdom),
  habitat_summary_allData  %>% dplyr::mutate(category = "Habitat",  breakdownBy = "All Data") %>% dplyr::rename(group = habitat),
  invasive_summary_allData %>% dplyr::mutate(category = "Invasive", breakdownBy = "All Data") %>% dplyr::rename(group = isInvasive),
  preClean_invasive_summary_allData %>% dplyr::mutate(category = "Invasive_preCleaning", breakdownBy = "All Data") %>% dplyr::rename(group = isInvasive)
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
