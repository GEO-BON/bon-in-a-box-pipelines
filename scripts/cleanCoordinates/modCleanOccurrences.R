

## Install required packages
#packages <- c("terra", "rjson", "raster", "dplyr", "CoordinateCleaner")
#new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
#if(length(new.packages)) install.packages(new.packages)

#install.packages("devtools")
#install.packages("Rtools")
#library("remotes")
# WorldClimTiles not in CRAN
library("devtools")
library("crul")
library("remotes")
options(timeout = max(60000000, getOption("timeout")))
#remotes::install_github("kapitzas/WorldClimTiles")

## Load required packages
library("terra")
library("rjson")
library("raster")
library("CoordinateCleaner")
library("dplyr")
library("WorldClimTiles")

## Load functions
#source(paste(Sys.getenv("SCRIPT_LOCATION"), "funcCleanCoordinates.R", sep = "/"))
source("/scripts/cleanCoordinates/funcCleanCoordinates.R")
## Receiving args
args <- commandArgs(trailingOnly=TRUE)
outputFolder <- args[1] # Arg 1 is always the output folder
cat(args, sep = "\n")


input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)

obs <- read.table(file = input$obs, sep = '\t', header = TRUE) 

#country_boundary <- raster::getData("GADM", country = "CAN", level = 1, download=TRUE, path=outputFolder) #
#quebec_boundary <- country_boundary[country_boundary$NAME_1 == "Québec",]
  
 # subDir <- file.path(outputFolder)

 # box_extent_bioclim <- WorldClimTiles::tile_name(quebec_boundary, "worldclim") # determine which WorldClim tiles your study area intersects with.

 # clim_tiles <- tile_get(box_extent_bioclim, name =  "worldclim", var="tmean", path = subDir) # for 0.5 arcmin worldclim tiles of 
  # predictors <- tile_merge(clim_tiles)



cleaningRes <-  cleanCoordinates(obs,
                              predictors = NULL,
                                 unique_id = "id",
                                 lon = "decimalLongitude", 
                                 lat = "decimalLatitude", 
                              species_col = "scientificName",
                              srs.obs = input$srs.obs,
                              srs.target = input$srs.target
                                 tests = c( 
                                            "equal",
                                            "zeros", 
                                            "duplicates", 
                                            "same_pixel",
                                          #  "centroids",
                                         #   "seas", 
                                          #  "urban",
                                          #  "gbif", 
                                         #   "institutions"
                                 ),
                                 capitals_rad = 10000,
                                 centroids_rad = 1000, 
                                 centroids_detail = "both", 
                                 inst_rad = 100, 
                                 range_rad = 0,
                                 zeros_rad = 0.5,
                                threshold_env = 0.5,
                             predictors_env = NULL,
                                 capitals_ref = NULL, 
                                 centroids_ref = NULL, 
                                 inst_ref = NULL, 
                                 range_ref = NULL,
                                 seas_ref = NULL, 
                                 seas_scale = 10,
                                 additions = NULL,
                                 urban_ref = NULL, 
                                 verbose = TRUE)
 
 #output <- list("observation" =  sprintf("%s/observationGbif.csv", getwd())) 
  output <- list(
                  "n.clean" =  nrow(cleaningRes$clean),
                  "n.flagged" =  nrow(cleaningRes$flagged)
                  ) 

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))

  

