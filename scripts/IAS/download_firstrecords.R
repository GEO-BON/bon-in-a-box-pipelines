library(jsonlite)
library(stringr)
library(duckdb)
library(dplyr)
library(rgbif)


input <- biab_inputs()
country_name <- input$country_name$country$englishName
iso3 <- input$country_name$country$ISO3

# First record data doi
doi <- "https://doi.org/10.5281/zenodo.18220953"
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

# Grab file that ends with .csv
target_url <- files_df$direct_link[grepl("\\.csv$", files_df$filename)]

con <- dbConnect(duckdb())

DBI::dbExecute(con, "INSTALL httpfs; LOAD httpfs;")

# safely quote the remote CSV url and the country literal
url_lit <- DBI::dbQuoteLiteral(con, target_url)
country_lit <- DBI::dbQuoteLiteral(con, country_name)

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

## Find a column matching 'location' (case-insensitive)
col_candidates <- fields_vec[tolower(fields_vec) == "location"]
if (length(col_candidates) == 0) {
  col_candidates <- fields_vec[grepl("location", fields_vec, ignore.case = TRUE)]
}
if (length(col_candidates) == 0) {
  DBI::dbDisconnect(con, shutdown = TRUE)
  stop("No 'location'-like column found in CSV. Columns: ", paste(fields_vec, collapse = ", "))
}

# Choose the first matching candidate and quote it as an identifier
col_name <- col_candidates[1]
col_ident <- DBI::dbQuoteIdentifier(con, col_name)

# Now run the filtered query safely
query <- paste0("SELECT * FROM tmp_firstrecords WHERE ", col_ident, " = ", country_lit)
first_records <- DBI::dbGetQuery(con, query)

# Cleanup
DBI::dbDisconnect(con, shutdown = TRUE)

##----------------------------
## Standardise habitat terms
##----------------------------
first_records <- first_records %>% dplyr::mutate(habitat = toupper(habitat)) %>% 
  dplyr::mutate(habitat = gsub(";","|",habitat)) %>%
  dplyr::mutate(habitat = dplyr::case_when(habitat == "" ~ "NODATA", TRUE ~ as.character(habitat))) 

UniqueHabitats <- first_records %>% 
  dplyr::mutate(habitat = gsub(";","|",habitat)) %>%
  dplyr::distinct(habitat) %>% 
  dplyr::arrange() %>%
  dplyr::mutate(habitat = dplyr::case_when(habitat == "" ~ "NODATA", TRUE ~ as.character(habitat))) %>%
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
  select(verbatim_name, kingdom)

FirstRecords <- FirstRecords %>%
  left_join(matches, by = c("taxon" = "verbatim_name"))  %>% 
  mutate(kingdom = toupper(kingdom)) %>%
  dplyr::mutate(ISO3 = iso3) # add iso3 column for country code
##----------------------------
## Write and save
##----------------------------
firstrecords_path <- file.path(outputFolder, "FirstRecords_cleaned.csv")
write.csv(FirstRecords, firstrecords_path, row.names = FALSE)
biab_output("firstrecords_cleaned", firstrecords_path)