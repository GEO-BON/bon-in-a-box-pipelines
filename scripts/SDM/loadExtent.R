
## Install required packages
packages <- c("rjson", "googledrive")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

## Load required packages

library("rjson")
library("sf")
library("terra")
library("googledrive")
drive_deauth()
## Receiving args
args <- commandArgs(trailingOnly=TRUE)
outputFolder <- args[1] # Arg 1 is always the output folder
cat(args, sep = "\n")


input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)

exdir <- paste0(outputFolder, "/data")
dir.create(exdir)
# Create destination data folder (if there isn't one)

# Specify googledrive url:

test_shp = drive_get(as_id(input$url))
# Download zipped folder
drive_download(test_shp, path = file.path(outputFolder, "test_shp.zip"))
# Unzip folder
zip::unzip(zipfile = file.path(outputFolder, "test_shp.zip"), exdir = exdir, junkpaths = TRUE)
# Load test.shp
test_shp <- terra::vect(file.path(exdir, paste0(input$shp_name,".shp")))

study_extent_shp <- file.path(outputFolder, "study_extent.shp")
terra::writeVector(test_shp, study_extent_shp)


output <- list(
    "extent" = study_extent_shp ) 
  jsonData <- toJSON(output, indent=2)
  write(jsonData, file.path(outputFolder,"output.json"))