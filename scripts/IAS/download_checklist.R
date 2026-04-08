library(tidyRSS)
library(dplyr)
library(tidyr)
library(rvest)
library(stringr)
library(XML)

input <- biab_inputs()

country_name <- input$country_name$country$englishName
print(country_name)
print(class(country_name))

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
  dplyr::filter(country == country_name)
  print("feed match")
print(feed_match)

# Get details of checklist
name = feed_match$country
name = stringr::str_trim(name, side = c("both"))
name = gsub("[^[:alnum:]]", "_", name)

type = feed_match$item_type

version = feed_match$version
version = stringr::str_trim(version, side = c("both"))

# Get country-specific page content and search for download link to zip file
 url <- feed_match$item_link
  html <- rvest::read_html(url)
  tables <-
    html |> rvest::html_elements("table") |> rvest::html_children()
  url <- tables[[1]] |>
    rvest::html_element("a") |>
    rvest::html_attr(name = "href")

# Downloads with specified name into specified location - needs to be country name when looped + subfolders?

  download.file(url,
                destfile = file.path(outputFolder,"temp.zip"),
                mode = 'wb')
  unzip(file.path(outputFolder,"temp.zip"), exdir = outputFolder)
  
  species <- read.csv(file.path(outputFolder, "speciesprofile.txt"),
                      sep = "\t",
                      quote = "")
  taxon <- read.csv(file.path(outputFolder, "taxon.txt"), sep = "\t", quote = "")
  dist <- read.csv(file.path(outputFolder, "distribution.txt"), sep = "\t", quote = "")

    # Download and extract relevant meta data
  meta <- XML::xmlParse(file.path(outputFolder, "eml.xml"))
  meta <- XML::xmlToList(meta)

  alternativeIdentifier <- meta$dataset$alternateIdentifier
  publicationDate <-
    trimws(gsub("\n", "", meta$dataset$pubDate), which = "both")
  
  # bounding box of the country
  northBoundingCoordinate <-
    meta$dataset$coverage$geographicCoverage$boundingCoordinates$northBoundingCoordinate
  southBoundingCoordinate <-
    meta$dataset$coverage$geographicCoverage$boundingCoordinates$southBoundingCoordinate
  eastBoundingCoordinate <-
    meta$dataset$coverage$geographicCoverage$boundingCoordinates$eastBoundingCoordinate
  westBoundingCoordinate <-
    meta$dataset$coverage$geographicCoverage$boundingCoordinates$westBoundingCoordinate

# Remove temp file once complete
unlink(file.path(outputFolder,"temp.zip"))

# Unify the "distribution" text file to the other invasive status/species profile
 join_1 <- species |>
   dplyr::left_join(taxon, by = c("id" = "taxonID"))
 griis_checklist <- join_1 |> dplyr::left_join(dist, by = c("id" = "id"))  

# Gather summary statistics for list
 DATE <- Sys.Date()
 summary <- tidyr::tibble(
    downloadDate = DATE,
    name = gsub("_", " ", gsub("__", ", ", name)),
    checklistType = type,
    checklistLevel = ifelse(stringr::str_detect(name, ","), "Secondary", "Primary"),
    version = version,
    speciesCount = nrow(griis_checklist),
    invasiveCount = griis_checklist %>% dplyr::filter(isInvasive == "Invasive") %>% nrow()
  )
  
  # Gather Data for file directory
  directory <- tidyr::tibble(
    fileName = paste0(name, "_v", version, ".csv"),
    downloadDate = DATE,
    name = gsub("_", " ", gsub("__", ", ", name)),
    checklistType = type,
    checklistLevel = ifelse(stringr::str_detect(name, ","), "Secondary", "Primary"),
    version = version,
    northBoundingCoordinate = northBoundingCoordinate,
    southBoundingCoordinate = southBoundingCoordinate,
    eastBoundingCoordinate = eastBoundingCoordinate,
    westBoundingCoordinate = westBoundingCoordinate,
    alternativeIdentifier = alternativeIdentifier,
    url = url,
    publicationDate = publicationDate
  ) 
  
  checklist_path <- file.path(outputFolder, "GRIIS_checklist.csv")

  # Save checklist
  write.csv(griis_checklist,checklist_path)
  biab_output("griis_checklist", checklist_path)

