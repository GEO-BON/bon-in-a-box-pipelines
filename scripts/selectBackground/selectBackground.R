

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
source("/scripts/utils/utils.R")
source("/scripts/utils/predictors_func.R")

## Receiving args
args <- commandArgs(trailingOnly=TRUE)
outputFolder <- args[1] # Arg 1 is always the output folder
cat(args, sep = "\n")

setwd(outputFolder)
input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)

study_extent <- sf::st_read(input$study_extent)
bbox <- sf::st_bbox(study_extent, crs = input$proj_to)

if (file.exists(input$layers)) {
layers <- read.table(file = input$layers, sep = '\t', header = F)[, 1]

  } else {
    layers <- input$layers
  }


predictors_nc <- 
  load_cube(stac_path = "http://io.biodiversite-quebec.ca/stac/",
            limit = 5000, 
            collections = c("chelsa-clim"), 
            use.obs = F,
            buffer.box = 0,
            layers = layers,
            bbox = bbox,
            srs.cube = input$proj_to,
            t0 = "1981-01-01",
            t1 = "1981-01-01",
            spatial.res = input$spatial_res, # in meters
            temporal.res = "P1Y",
            aggregation = "mean",
            resampling = "near") 

background <- create_background(
  predictors = predictors_nc, 
  species = input$species,
  mask = study_extent,
  lon = "lon",
  lat = "lat",
  method = "random", #will select random points in predictors_study_extent area
  n = input$n_background,
  density_bias = NULL) 

 
background.data <- file.path(outputFolder, "background.tsv")
write.table(background, background.data,
             append = F, row.names = F, col.names = T, sep = "\t")

head(background)
print("!!!")
  output <- list(
                  "n_background" =  nrow(background),
                  "clean_background"= background.data
                  
                  ) 

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))

  

