

## Install required packages
packages <- c("terra", "rjson", "raster", "dplyr", "CoordinateCleaner")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

## Load required packages
library("terra")
library("rjson")
library("raster")
library("CoordinateCleaner")
library("dplyr")


## Load functions
source(paste(Sys.getenv("SCRIPT_LOCATION"), "cleanCoordinates/funcCleanCoordinates.R", sep = "/"))
source("/scripts/utils/utils.R")
#source("/scripts/cleanCoordinates/funcCleanCoordinates.R")
## Receiving args
args <- commandArgs(trailingOnly=TRUE)
outputFolder <- args[1] # Arg 1 is always the output folder
cat(args, sep = "\n")


input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)

obs <- read.table(file = input$obs, sep = '\t', header = TRUE) 

if (is.null(input$predictors.dir) || input$predictors.dir == "...") {

predictors <- NULL
proj.to <- input$srs

} else {

predictors <- loadPredictors(input$predictors.dir,
                           subsetLayers = NULL,
                           removeCollinear = F,
                           loadNonCollinear = F) 
proj.to <- terra::crs(predictors, proj = T)

}

#obs <- create_projection(presence, lon = "decimalLongitude", lat = "decimalLatitude", 
#proj.from = input$srs.obs, proj.to = proj, new.lon = "lon", new.lat = "lat") 


cleaningRes <-  clean_coordinates(obs,
                              predictors = predictors,
                                 unique_id = "id",
                                 lon = "lon", 
                                 lat = "lat", 
                              species_col = "scientific_name",
                              srs = proj.to,
                              covars = input$covars,
                              spatial.res = input$spatial.res,
                                 tests = input$tests,
                                 capitals_rad = 10000,
                                 centroids_rad = 1000, 
                                 centroids_detail = "both", 
                                 inst_rad = 100, 
                                 range_rad = 0,
                                 zeros_rad = 0.5,
                                threshold_env = 0.8,
                                output_dir = outputFolder)
 
 #output <- list("observation" =  sprintf("%s/observationGbif.csv", getwd())) 
  output <- list("n.observations" =  nrow(obs)
                 "n.clean" =  nrow(cleaningRes$clean),
                  
                  ) 

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))

  

