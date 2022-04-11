## Install required packages
library(rjson)
library(sf)
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

presence <- read.table(file = input$presence, sep = '\t', header = TRUE) 

if (is.numeric(input$dist_buffer)) {
dist_buffer <- input$dist_buffer
} else { 
		dist_buffer <- NULL
	
}
study_extent <- create_study_extent(presence, 
                              lon = "lon",
                              lat = "lat",
                              proj = input$proj_to,
                              method = input$method,
                              dist_buffer = dist_buffer,
                              shapefile_path = NULL)


study_extent_shp <- file.path(outputFolder, "study_extent.shp")
sf::st_write(study_extent, study_extent_shp, append = FALSE  )


output <- list( "area_study_extent" = sf::st_area(study_extent) / 1000000,
    "study_extent" = study_extent_shp ) 
  jsonData <- toJSON(output, indent=2)
  write(jsonData, file.path(outputFolder,"output.json"))

