library(jsonlite)
library(data.table)
library(duckdb)

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
