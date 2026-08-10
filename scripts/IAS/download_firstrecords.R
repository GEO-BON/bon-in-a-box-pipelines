# This script downloads the first records data for a country and standardises the first records data to align with the terminology used in the GRIIS checklist

# load required libraries
library(jsonlite)
library(stringr)
library(duckdb)
library(dplyr)
library(rgbif)
library(openxlsx)

# load inputs
input <- biab_inputs()
country_name <- input$country_name$country$englishName
iso3 <- input$country_name$country$ISO3

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

if (is.null(iso3) || is.na(iso3) || iso3 == "") {
  stop("ISO3 is missing for selected country: ", country_name)
}

# First record data doi
doi <- "https://doi.org/10.5281/zenodo.18220953"
source_version <- "3.1.1"
source_filename <- paste0("SInAS_", source_version, ".csv")
# Extract the ID (the digits after the last dot)
record_id <- sub(".*\\.", "", doi)

# Use it in the API URL
api_url <- paste0("https://zenodo.org/api/records/", record_id)

# Fetch the metadata from the Zenodo API
metadata <- fromJSON(api_url)

# List all filenames and their direct links
files_df <- data.frame(
  filename = metadata$files$key,
  direct_link = metadata$files$links$self
)

print(files_df)

# Select the expected release file explicitly. Failing on zero or multiple
# matches prevents a future Zenodo file addition from silently changing input.
target_matches <- which(files_df$filename == source_filename)
if (length(target_matches) != 1) {
  stop(
    "Expected exactly one Zenodo file named ", source_filename,
    "; found ", length(target_matches), ". Available files: ",
    paste(files_df$filename, collapse = ", ")
  )
}
target_url <- files_df$direct_link[[target_matches]]

# Original P3 assigns every SInAS location associated with the selected ISO3
# to that country (for example Australia, Tasmania and Lord Howe Islands).
locations <- openxlsx::read.xlsx(config_file("AllLocations.xlsx"), sheet = 2)
required_location_columns <- c("locationID", "ISO3", "location")
missing_location_columns <- setdiff(required_location_columns, names(locations))
if (length(missing_location_columns) > 0) {
  stop(
    "AllLocations.xlsx is missing columns: ",
    paste(missing_location_columns, collapse = ", ")
  )
}
country_locations <- locations %>%
  dplyr::filter(ISO3 == iso3) %>%
  dplyr::select(locationID, location) %>%
  dplyr::distinct()
if (nrow(country_locations) == 0) {
  stop("No SInAS locations are mapped to ISO3 ", iso3, " in AllLocations.xlsx.")
}

con <- dbConnect(duckdb())

DBI::dbExecute(con, "INSTALL httpfs; LOAD httpfs;")

# Safely quote the remote CSV URL.
url_lit <- DBI::dbQuoteLiteral(con, target_url)

# create a temporary table from the CSV (DuckDB will stream/parse it)
## The CSV uses quoted fields separated by spaces; specify delim=' '
DBI::dbExecute(con, paste0(
  "CREATE TEMPORARY TABLE tmp_firstrecords AS SELECT * FROM read_csv_auto(", 
  url_lit, ", header=TRUE, delim=' ')")
)

## Inspect actual column names discovered by DuckDB
fields_raw <- DBI::dbListFields(con, "tmp_firstrecords")

## DBI/driver may sometimes return a single string containing all quoted names
## e.g. '"location" "locationID" "taxon" ...'. Detect and extract real names.
if (length(fields_raw) == 1 && grepl('"', fields_raw)) {
  matches <- regmatches(fields_raw, gregexpr('"([^\"]+)"', fields_raw))
  fields_vec <- gsub('^"|"$', '', matches[[1]])
} else {
  fields_vec <- fields_raw
}

message("Columns in CSV: ", paste(fields_vec, collapse = ", "))

## Filter by stable SInAS location IDs rather than an exact country-name match.
location_id_candidates <- fields_vec[tolower(fields_vec) == "locationid"]
if (length(location_id_candidates) == 0) {
  DBI::dbDisconnect(con, shutdown = TRUE)
  stop("No 'locationID' column found in CSV. Columns: ", paste(fields_vec, collapse = ", "))
}

# Quote each configured ID as a SQL literal. Casting the source value to text
# tolerates differences in inferred integer types without discarding IDs.
col_ident <- DBI::dbQuoteIdentifier(con, location_id_candidates[[1]])
location_literals <- vapply(
  as.character(country_locations$locationID),
  function(value) as.character(DBI::dbQuoteLiteral(con, value)),
  character(1)
)

# Preserve the original location and locationID columns in the returned rows.
query <- paste0(
  "SELECT * FROM tmp_firstrecords WHERE CAST(", col_ident,
  " AS VARCHAR) IN (", paste(location_literals, collapse = ", "), ")"
)
first_records <- DBI::dbGetQuery(con, query)

# Cleanup
DBI::dbDisconnect(con, shutdown = TRUE)

if (nrow(first_records) == 0) {
  stop(
    "No SInAS records found for the configured locations associated with ",
    country_name, " (", iso3, ")."
  )
}

##----------------------------
## Standardise habitat terms
##----------------------------
first_records <- first_records %>% dplyr::mutate(habitat = toupper(habitat)) %>% 
  dplyr::mutate(habitat = gsub(";","|",habitat)) %>%
  dplyr::mutate(habitat = dplyr::case_when(is.na(habitat) | habitat == "" ~ "NODATA", TRUE ~ as.character(habitat)))

UniqueHabitats <- first_records %>% 
  dplyr::mutate(habitat = gsub(";","|",habitat)) %>%
  dplyr::distinct(habitat) %>% 
  dplyr::arrange() %>%
  dplyr::mutate(habitat = dplyr::case_when(is.na(habitat) | habitat == "" ~ "NODATA", TRUE ~ as.character(habitat))) %>%
  dplyr::mutate(terrestrial = dplyr::case_when(grepl(c("TERRESTRIAL"), habitat) ~ "TERRESTRIAL ", TRUE ~ ""),
                marine = dplyr::case_when(grepl("MARINE", habitat) ~ "MARINE ", TRUE ~ ""),
                freshwater = dplyr::case_when(grepl(c("FRESHWATER"), habitat) ~ "FRESHWATER ", TRUE ~ ""),
                brackish = dplyr::case_when(grepl("BRACKISH", habitat) ~ "BRACKISH ", TRUE ~ ""),
                nodata = dplyr::case_when(grepl("NODATA", habitat) ~ "NODATA ", TRUE ~ "")) %>% 
  dplyr::mutate(habitatStandardised = paste(terrestrial,marine,freshwater,brackish,nodata)) %>% 
  dplyr::mutate(habitatStandardised = stringr::str_trim(habitatStandardised, side = "both")) %>%
  dplyr::mutate(habitatStandardised = stringr::str_squish(habitatStandardised)) %>%
  dplyr::mutate(habitatStandardised = gsub(" ","|",habitatStandardised)) %>% 
  dplyr::select(habitat,habitatStandardised) 

FirstRecords <- dplyr::left_join(first_records, UniqueHabitats, by = "habitat") %>% 
  dplyr::select(-habitat) %>% 
  dplyr::rename(habitat = habitatStandardised)

##----------------------------
## Add taxonomic information
##----------------------------
unique_names <- unique(FirstRecords$taxon)

matches <- name_backbone_checklist(unique_names) %>%
  select(verbatim_name, kingdom) %>%
  rename(kingdom_gbif = kingdom)

FirstRecords <- FirstRecords %>%
  dplyr::select(-dplyr::any_of("kingdom")) %>%
  left_join(matches, by = c("taxon" = "verbatim_name"))  %>% 
  mutate(kingdom = toupper(kingdom_gbif)) %>%
  dplyr::select(-kingdom_gbif) %>%
  dplyr::mutate(
    kingdom = dplyr::if_else(is.na(kingdom) | kingdom == "", "NODATA", kingdom),
    ISO3 = iso3,
    sourceVersion = source_version,
    sourceDOI = doi,
    sourceFile = source_filename
  )

# Preserve the release's taxaGroup values when supplied. The current main CSV
# may not contain this companion-taxonomy field, so retain a stable output
# schema and report the absence rather than inventing a classification.
if (!"taxaGroup" %in% names(FirstRecords)) {
  warning("SInAS ", source_version, " does not provide taxaGroup in ", source_filename, "; using NODATA.")
  FirstRecords$taxaGroup <- "NODATA"
} else {
  FirstRecords$taxaGroup <- dplyr::if_else(
    is.na(FirstRecords$taxaGroup) | FirstRecords$taxaGroup == "",
    "NODATA",
    as.character(FirstRecords$taxaGroup)
  )
}
##----------------------------
## Write and save
##----------------------------
firstrecords_path <- file.path(outputFolder, "FirstRecords_cleaned.csv")
write.csv(FirstRecords, firstrecords_path, row.names = FALSE)
biab_output("firstrecords_cleaned", firstrecords_path)
