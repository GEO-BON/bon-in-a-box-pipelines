library(gh)
library(tidyverse)

files <- gh("GET /repos/{owner}/{repo}/contents/{path}",
            owner = "OHI-Science",
            repo  = "ohi-global",
            path  = "eez/layers")

file_names <- vapply(files, function(x) x$name, character(1))
download_urls <- vapply(files, function(x) x$download_url, character(1))

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

### Need to filter by region ID

biab_output("species_layers", spp_file_paths)