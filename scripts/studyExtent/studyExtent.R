## Install required packages
packages <- c("terra", "rjson", "raster", "dplyr", "CoordinateCleaner", "sf")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

## Load required packages
library("terra")
library("rjson")
library("raster")
library("CoordinateCleaner")
library("dplyr")


## Load functions
source(paste(Sys.getenv("SCRIPT_LOCATION"), "studyExtent/funcStudyExtent.R", sep = "/"))
source("/scripts/utils/utils.R")

## Receiving args
args <- commandArgs(trailingOnly=TRUE)
outputFolder <- args[1] # Arg 1 is always the output folder
cat(args, sep = "\n")


input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)

obs <- read.table(file = input$obs, sep = ';', header = TRUE) 
obs <- dplyr::filter(obs,
                                 .summary == T) %>% # summary = TRUE means the observations was identified as an outlier at least once during the cleaning procedure
          dplyr::select(id, scientific_name, lon, lat) 


if (is.numeric(input$dist.buffer)) {
dist_buffer <- input$dist.buffer
} else { 
		dist_buffer <- NULL
	
}
study_extent <- create_study_extent(obs, 
                              lon = "lon",
                              lat = "lat",
                              proj = input$srs,
                              method = input$method,
                              dist_buffer = dist_buffer,
                              shapefile_path = NULL)


study_extent_shp <- file.path(outputFolder, "study_extent.shp")
sf::st_write(study_extent, study_extent_shp, append = FALSE  )


output <- list(
                  "area_study_extent" = sf::st_area(study_extent) / 1000000
                  ) 
  jsonData <- toJSON(output, indent=2)
  write(jsonData, file.path(outputFolder,"output.json"))

