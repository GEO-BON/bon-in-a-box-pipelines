library(jsonlite)
library(duckdb)
library(dplyr)

input <- biab_inputs()
country_name <- input$country_name$country$englishName

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

# parsing by country "location" because the file is so big
con <- dbConnect(duckdb())
dbExecute(con, "INSTALL httpfs; LOAD httpfs;")

query <- paste0("
  SELECT * FROM read_csv_auto('", target_url, "', delim=' ', header=True)
  WHERE location = country_name
")

first_records <- dbGetQuery(con, query)

# Close connection
dbDisconnect(con, shutdown = TRUE)

# Standardise habitat terms
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
