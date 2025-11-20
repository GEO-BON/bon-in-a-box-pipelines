library(tidyverse)
library(gh)

input <- biab_inputs()

scenario_years <- c(input$start_year:input$end_year)

# Path to OHI global repository
repo_path <- "https://raw.githubusercontent.com/OHI-Science/ohi-global/draft"

# Mke a list of input layers related to biodiversity
files <- gh("GET /repos/{owner}/{repo}/contents/{path}",
            owner = "OHI-Science",
            repo  = "ohi-global",
            path  = "eez/layers")

# Extract file names
# Eventually this will not be necessary because data will be piping into the pipeline
file_names <- sapply(files, function(x) x$name) 
file_names_bd <- file_names[grepl("spp|species|hab|coral|mangrove|seagrass|eelgrass", file_names, ignore.case=TRUE)]
print(file_names_bd)

# Run config file
source()