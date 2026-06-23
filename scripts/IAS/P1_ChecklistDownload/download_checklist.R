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
ifelse(is.na(iso3), print("ISO3 code is missing"), print("ISO3 code is present"))
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

for (i in 1:nrow(feed_match)) {

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
# setting output paths
checklist_path <- file.path(outputFolder, "GRIIS_checklist.csv")
summary_path <- file.path(outputFolder, "GRIIS_summary.csv")
directory_path <- file.path(outputFolder, "GRIIS_directory.csv")

griis_checklists <- dplyr::bind_rows(checklist_list)
summaries <- dplyr::bind_rows(summary_list)
directory <- dplyr::bind_rows(directory_list)

write.csv(griis_checklists, checklist_path, row.names = FALSE)
write.csv(summaries, summary_path, row.names = FALSE)
write.csv(directory, directory_path, row.names = FALSE)
biab_output("griis_checklist", checklist_path)
biab_output("griis_summary", summary_path)
biab_output("griis_directory", directory_path)
