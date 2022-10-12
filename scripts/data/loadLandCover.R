

## Install required packages

packages <- c("terra", "rjson", "raster", "dplyr", "CoordinateCleaner", "lubridate", "rgdal", "remotes")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)


##devtools::install_local("loadLandCover/stac-catalogue-main.zip", 
  #  repos = NULL, 
 #   type = "source")

## Load required packages
library("terra")
library("rjson")
library("raster")
library("dplyr")
library("stacatalogue")
library("gdalcubes")
library("RCurl")
library(sf)
options(timeout = max(60000000, getOption("timeout")))

## Receiving args
args <- commandArgs(trailingOnly=TRUE)
outputFolder <- args[1] # Arg 1 is always the output folder
cat(args, sep = "\n")


input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)

# Tranform the vector to a bbox object
bbox <- sf::st_bbox(c(xmin = input$bbox_coordinates[1], xmax = input$bbox_coordinates[2], 
            ymax = input$bbox_coordinates[3], ymin = input$bbox_coordinates[4]), crs = st_crs(input$proj_to))

n_year <- as.integer(substr(input$t1, 1, 4)) - as.integer(substr(input$t0, 1, 4)) + 1 
temporal_res <- paste0("P", n_year, "Y")

if (input$stac_source == "IO") {
  lc_raster <- stacatalogue::load_prop_values(stac_path = "https://io.biodiversite-quebec.ca/stac/",
                                collections = c("esacci-lc"), 
                              bbox = bbox,
                               srs.cube = input$proj_to,
                               limit = 5000,
                                t0 = input$t0,
                                t1 = input$t1,
                                spatial.res = input$spatial_res, # in meters
                                prop = input$proportion,
                                prop.res = input$proportion_res,
                                select_values = input$lc_classes,
                                temporal.res =  temporal_res)
  } else if (input$stac_source == "PC") {
  lc_raster <- stacatalogue::load_prop_values_pc(stac_path =  "https://planetarycomputer.microsoft.com/api/stac/v1/",
                                collections = c("io-lulc-9-class"), 
                              bbox = bbox,
                               srs.cube = input$proj_to,
                                t0 = input$t0,
                                t1 = input$t1,
                                limit = 5000,
                                spatial.res = input$spatial_res, # in meters
                                prop = input$proportion,
                                prop.res = input$proportion_res,
                                select_values = input$lc_classes,
                                temporal.res =  temporal_res)
}



output_nc_predictors <- file.path(outputFolder, "lc.tif")
raster::writeRaster(x = lc_raster,
                          output_nc_predictors,
                          overwrite = TRUE)
 
output <- list(
  "output_lc" =  output_nc_predictors
                  ) 
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))