library(zen4R)
# actually just read the file so we don't have to download it every time
doi <- "https://doi.org/10.5281/zenodo.5562891"
file_name <- "SInAS_3.1.1.csv"
download <- download_zenodo(doi, file_name, path = "scripts/IAS", overwrite = TRUE)
