library(gh)
library(tidyverse)

# Download csv files of layers from the github repository

# Connect to all file names in the layers folder of the repo
files <- gh("GET /repos/{owner}/{repo}/contents/{path}",
            owner = "OHI-Science",
            repo  = "ohi-global",
            path  = "eez/layers")

# Extract only the names and download URLs of the habitat layers
file_names <- vapply(files, function(x) x$name, character(1))
print(file_names)
file_names_hab <- file_names[grepl("hab", file_names, ignore.case = TRUE)]
print(file_names_hab)
download_urls <- vapply(files, function(x) x$download_url, character(1))

download_urls_hab <- download_urls[file_names %in% file_names_hab]
print(download_urls_hab)

# Loop through and save
hab_file_paths <- c()
for (i in seq_along(file_names_hab)) {
  dest <- file.path(outputFolder, file_names_hab[i])
  download.file(download_urls_hab[i], destfile = dest, mode = "wb")
  cat("Saved:", dest, "\n")
  hab_file_paths <- rbind(hab_file_paths, dest)
}

biab_output("habitat_layers", hab_file_paths)

# Download species file paths
file_names_spp <- file_names[grepl("spp", file_names, ignore.case = TRUE)]
download_urls_spp <- download_urls[file_names %in% file_names_spp]
print(download_urls_spp)

spp_file_paths <- c()
for (i in seq_along(file_names_spp)) {
  dest <- file.path(outputFolder, file_names_spp[i])
  download.file(download_urls_spp[i], destfile = dest, mode = "wb")
  cat("Saved:", dest, "\n")
  spp_file_paths <- rbind(spp_file_paths, dest)
}

biab_output("species_layers", spp_file_paths)


# Download pressure data
resilience <- read.csv("https://raw.githubusercontent.com/OHI-Science/ohi-global/draft/eez/conf/resilience_matrix.csv", stringsAsFactors = FALSE, na.strings = c("", "NA"))
print(resilience)

pressures <- read.csv("https://raw.githubusercontent.com/OHI-Science/ohi-global/draft/eez/conf/pressures_matrix.csv", stringsAsFactors = FALSE, na.strings = c("", "NA"))
print(pressures)

# Filter only BD-related layers
bd_pressure_layers <- pressures[pressures$goal %in% c('HAB', 'SPP'), ]
bd_pressure_layers <- bd_pressure_layers[rowSums(!is.na(bd_pressure_layers[, 4:ncol(bd_pressure_layers)])) > 0, ]
print(colnames(bd_pressure_layers))
# Save filtered matrix
pressure_matrix_path <- file.path(outputFolder, "pressures_matrix_bd.csv")
write.csv(bd_pressure_layers, pressure_matrix_path, row.names=FALSE)
biab_output("pressure_matrix_bd", pressure_matrix_path) 

cols <- paste(colnames(bd_pressure_layers), collapse="|")
file_names_pressure <- file_names[str_detect(file_names, regex(cols, ignore_case = TRUE))]
print(file_names_pressure)
download_urls_pressure <- download_urls[file_names %in% file_names_pressure]

pressures_file_paths <- c()
for (i in seq_along(file_names_pressure)) {
  dest <- file.path(outputFolder, file_names_pressure[i])
  download.file(download_urls_pressure[i], destfile = dest, mode = "wb")
  cat("Saved:", dest, "\n")
  pressures_file_paths <- rbind(pressures_file_paths, dest)
}

biab_output("pressures_layers", pressures_file_paths)


## Load resilience matrix and filter for the rows that appy to biodiversity goal
bd_resilience_layers <- resilience[resilience$goal %in% c('HAB', 'SPP'), ]
bd_resilience_layers <- bd_resilience_layers[
  rowSums(bd_resilience_layers[, 4:ncol(bd_resilience_layers)] == "x", na.rm = TRUE) > 0,
]
print(colnames(bd_resilience_layers))

resilience_matrix_path <- file.path(outputFolder, "resilience_matrix_bd.csv")
write.csv(bd_resilience_layers, resilience_matrix_path, row.names=FALSE)
biab_output("resilience_matrix_bd", resilience_matrix_path) 


cols <- paste(colnames(bd_resilience_layers), collapse="|")
file_names_resilience <- file_names[str_detect(file_names, regex(cols, ignore_case = TRUE))]
print(file_names_resilience)
download_urls_resilience <- download_urls[file_names %in% file_names_resilience]

resilience_file_paths <- c()
for (i in seq_along(file_names_resilience)) {
  dest <- file.path(outputFolder, file_names_resilience[i])
  download.file(download_urls_resilience[i], destfile = dest, mode = "wb")
  cat("Saved:", dest, "\n")
  resilience_file_paths <- rbind(resilience_file_paths, dest)
}

biab_output("resilience_layers", resilience_file_paths)