

## Install required packages
packages <- c("terra", "rjson", "raster", "dplyr", "CoordinateCleaner", "stars")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

## Load required packages
library("terra")
library("rjson")
library("raster")
library("CoordinateCleaner")
library("dplyr")
library("stars")

## Load functions
source(paste(Sys.getenv("SCRIPT_LOCATION"), "selectBackground/funcSelectBackground.R", sep = "/"))
source("/scripts/extractPredictors/funcExtractPredictors.R")
source("/scripts/utils/utils.R")
#source("/scripts/cleanCoordinates/funcCleanCoordinates.R")
## Receiving args
args <- commandArgs(trailingOnly=TRUE)
outputFolder <- args[1] # Arg 1 is always the output folder
cat(args, sep = "\n")

setwd(outputFolder)
input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)

study_extent <- sf::st_read(input$study_extent)
bbox <- sf::st_bbox(study_extent, crs = input$srs)
cube <- 
  load_cube(stac_path = "http://io.biodiversite-quebec.ca/stac/",
            limit = 5000, 
            collections = c("chelsa-clim"), 
            use.obs = F,
            buffer.box = 0,
            layers = input$layers,
            left = bbox$xmin,
            right =  bbox$xmax,
            bottom = bbox$ymin,
            top = bbox$ymax,
            srs.cube = input$srs,
            t0 = "1981-01-01",
            t1 = "1981-01-01",
            spatial.res = 1000, # in meters
            temporal.res = "P1Y",
            aggregation = "mean",
            resampling = "near") 

predictors_study_extent <- gdalcubes::filter_geom(cube,  sf::st_geometry(study_extent, crs = "EPSG:6623"), srs = "EPSG:6623")

predictors_study_extent <- cube_to_raster(predictors_study_extent, format = "terra")

background <- create_background(
                                   predictors_study_extent, 
                                    lon = "lon",
                                    lat = "lat",
                                    species = input$species,
                                    method = input$method_background, #will select random points in predictors_study_extent area
                                    n = input$n_background,
                                   density_bias = NULL) 

 
background.data <- file.path(outputFolder, "background.tsv")
write.table(background, background.data,
             append = F, row.names = F, col.names = T, sep = "\t")


  output <- list(
                  "n.background" =  nrow(background),
                  "data"= background.data
                  
                  ) 

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))

  

