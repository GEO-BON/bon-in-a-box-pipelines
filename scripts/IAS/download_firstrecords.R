# This script downloads the first records data for a country and standardises the first records data to align with the terminology used in the GRIIS checklist

# load required libraries
library(jsonlite)
library(stringr)
library(duckdb)
library(dplyr)
library(openxlsx)

# load inputs
input <- biab_inputs()
country_name <- input$country_name$country$englishName
iso3 <- input$country_name$country$ISO3
# BON country selectors can supply a suffixed code such as AUS_1.
# SInAS uses the standard three-letter code for country/location matching.
iso3 <- sub("_[0-9]+$", "", toupper(trimws(as.character(iso3))))
if (length(iso3) != 1L || is.na(iso3) || !grepl("^[A-Z]{3}$", iso3)) {
  stop("Select a country with a valid three-letter ISO3 code.")
}

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
doi <- "https://doi.org/10.5281/zenodo.15793812"
source_version <- "3.0"
source_filename <- paste0("SInAS_", source_version, ".csv")
taxonomy_filename <- paste0("SInAS_", source_version, "_FullTaxaList.csv")
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
release_file_url <- function(filename, files) {
  matches <- which(files$filename == filename)
  if (length(matches) != 1) {
    stop(
      "Expected exactly one Zenodo file named ", filename,
      "; found ", length(matches), ". Available files: ",
      paste(files$filename, collapse = ", ")
    )
  }
  files$direct_link[[matches]]
}
target_url <- release_file_url(source_filename, files_df)
taxonomy_url <- release_file_url(taxonomy_filename, files_df)

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

# The companion table must come from the same pinned release: its taxonIDs
# belong to that release, not to GBIF or to a subsequent preparation run.
taxonomy_url_lit <- DBI::dbQuoteLiteral(con, taxonomy_url)
source_taxonomy <- DBI::dbGetQuery(con, paste0(
  "SELECT taxonID, kingdom, taxaGroup FROM read_csv_auto(",
  taxonomy_url_lit, ", header=TRUE, delim=' ', nullstr=['', 'NA'])")
)

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
# Reproduce original P2: keep the first taxonomy entry for each taxonID and
# left-join kingdom and taxaGroup before the preparation step filters kingdoms.
# Do not replace missing source taxonomy with live name-matching results.
JoinSourceTaxonomy <- function(records, taxonomy) {
  required <- c("taxonID", "kingdom", "taxaGroup")
  missing <- setdiff(required, names(taxonomy))
  if (!"taxonID" %in% names(records) || length(missing) > 0) {
    stop("Source records require taxonID and companion taxonomy requires: ",
         paste(required, collapse = ", "))
  }
  taxa_info <- taxonomy %>%
    dplyr::select(dplyr::all_of(required)) %>%
    dplyr::distinct(taxonID, .keep_all = TRUE)
  joined <- records %>%
    dplyr::select(-dplyr::any_of(c("kingdom", "taxaGroup"))) %>%
    dplyr::left_join(taxa_info, by = "taxonID", na_matches = "never") %>%
    dplyr::mutate(
      kingdom = toupper(kingdom),
      kingdom = dplyr::if_else(is.na(kingdom) | kingdom == "", "NODATA", kingdom)
    )
  missing_kingdom <- joined$kingdom == "NODATA"
  missing_group <- is.na(joined$taxaGroup) | joined$taxaGroup == ""
  unmatched_id <- is.na(joined$taxonID) | !joined$taxonID %in% taxa_info$taxonID
  issues <- joined %>%
    dplyr::select(dplyr::any_of(c("taxonID", "taxon", "kingdom", "taxaGroup"))) %>%
    dplyr::mutate(
      missing_taxonID_match = unmatched_id,
      missing_kingdom = missing_kingdom,
      missing_taxaGroup = missing_group
    ) %>%
    dplyr::filter(missing_taxonID_match | missing_kingdom | missing_taxaGroup) %>%
    dplyr::distinct()
  list(data = joined, issues = issues)
}

taxonomy_result <- JoinSourceTaxonomy(FirstRecords, source_taxonomy)
FirstRecords <- taxonomy_result$data %>%
  dplyr::mutate(
    ISO3 = iso3,
    sourceVersion = source_version,
    sourceDOI = doi,
    sourceFile = source_filename,
    sourceTaxonomyFile = taxonomy_filename
  )
if (nrow(taxonomy_result$issues) > 0) {
  warning(nrow(taxonomy_result$issues),
          " distinct source taxonomy entries have missing matches or fields; see taxonomy issues.")
}
##----------------------------
## Write and save
##----------------------------
firstrecords_path <- file.path(outputFolder, "FirstRecords_cleaned.csv")
write.csv(FirstRecords, firstrecords_path, row.names = FALSE)
taxonomy_issues_path <- file.path(outputFolder, "FirstRecords_taxonomy_issues.csv")
write.csv(taxonomy_result$issues, taxonomy_issues_path, row.names = FALSE, na = "")
biab_output("firstrecords_cleaned", firstrecords_path)
biab_output("taxonomy_issues", taxonomy_issues_path)
