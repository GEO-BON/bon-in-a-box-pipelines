

## Install required packages
packages <- c("terra", "rjson", "raster", "stars", "dplyr", "CoordinateCleaner", "lubridate", "rgdal", "remotes", "RCurl")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)
Sys.setenv("R_REMOTES_NO_ERRORS_FROM_WARNINGS" = "true")
library("devtools")
if (!"stacatalogue" %in% installed.packages()[,"Package"]) devtools::install_github("ReseauBiodiversiteQuebec/stac-catalogue")
if (!"gdalcubes" %in% installed.packages()[,"Package"]) devtools::install_github("appelmar/gdalcubes_R")


## Load required packages

#install.packages("gdalcubes")
library("terra")
library("rjson")
library("raster")
library("dplyr")
library("stacatalogue")
library("gdalcubes")


## Load functions
source(paste(Sys.getenv("SCRIPT_LOCATION"), "SDM/loadPredictorsFunc.R", sep = "/"))
source(paste(Sys.getenv("SCRIPT_LOCATION"), "SDM/sdmUtils.R", sep = "/"))

## Receiving args
args <- commandArgs(trailingOnly=TRUE)
outputFolder <- args[1] # Arg 1 is always the output folder
cat(args, sep = "\n")


input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)


# Case 1: we create an extent from a set of observations
bbox <- sf::st_bbox(c(xmin = input$bbox[1], ymin = input$bbox[2], 
            xmax = input$bbox[3], ymax = input$bbox[4]), crs = sf::st_crs(input$proj)) 


if(is.null(input$nb_sample)) {
  sample <- FALSE 
  } else {
    sample <- TRUE
  }

if(length(input$layers) == 0) {
  layers <- NULL 
  } else {
    layers <- input$layers
  }
if(length(input$variables) == 0) {
  variables <- NULL 
  } else {
    variables <- input$variables
  }

predictors <- load_predictors(source = "cube",
                            cube_args = list(stac_path = "http://io.biodiversite-quebec.ca/stac/",
            limit = 5000, 
            collections = input$collection,     
            t0 = "1981-01-01",
            t1 = "1981-01-01",
            spatial.res = input$spatial_res, # in meters
            temporal.res = "P1Y",
            aggregation = "mean",
            resampling = "near"),
                          
                           subset_layers = layers,
                           variables = variables,
                           remove_collinear = input$remove_collinearity,
                           method = input$method,
                           method_cor_vif = input$method_cor_vif,
                           proj = input$proj,
                           bbox = bbox,
                           sample = sample,
                           nb_points = input$nb_sample,
                           cutoff_cor = input$cutoff_cor,
                           cutoff_vif = input$cutoff_vif,
                           export = F,
                           ouput_dir = getwd(),
                           as_list = F)


# Mask
if(!is.null(input$mask) && length(input$mask)>1) {

  mask <- terra::vect(input$mask)
  predictors <- fast_crop(predictors, mask)
  }

output_predictors <- file.path(outputFolder, "predictors.tif")

terra::writeRaster(predictors, output_predictors, overwrite = T, gdal=c("COMPRESS=DEFLATE"), filetype="COG")
output <- list("predictors" = output_predictors) 
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))