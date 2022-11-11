

## Install required packages

library("devtools")
#devtools::install_github("ReseauBiodiversiteQuebec/stac-catalogue", upgrade = "never")
remotes::install_github("appelmar/gdalcubes_R")

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
options(timeout = max(60000000, getOption("timeout")))

## Receiving args
args <- commandArgs(trailingOnly=TRUE)
outputFolder <- args[1] # Arg 1 is always the output folder
cat(args, sep = "\n")


input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)


# Tranform the vector to a bbox object
bbox <- sf::st_bbox(c(xmin = input$bbox[1], ymin = input$bbox[2], 
            xmax = input$bbox[3], ymax = input$bbox[4]), sf::crs = st_crs(input$proj)) 

n_year <- as.integer(substr(input$t1, 1, 4)) - as.integer(substr(input$t0, 1, 4)) + 1 
temporal_res <- paste0("P", n_year, "Y")

if (input$stac_source == "IO") {
  lc_raster <- stacatalogue::load_prop_values(stac_path = "https://io.biodiversite-quebec.ca/stac/",
                                collections = c("esacci-lc"), 
                              bbox = bbox,
                               srs.cube = input$proj,
                               limit = input$stac_limit,
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
                               srs.cube = input$proj,
                                t0 = input$t0,
                                t1 = input$t1,
                                limit = input$stac_limit,
                                spatial.res = input$spatial_res, # in meters
                                prop = input$proportion,
                                prop.res = input$proportion_res,
                                select_values = input$lc_classes,
                                temporal.res =  temporal_res)
}



output_nc_predictors <- file.path(outputFolder, "lc.tif")
raster::writeRaster(x = lc_raster,
                          output_nc_predictors,
                          format='COG',
                          options=c("COMPRESS=DEFLATE"),
                          overwrite = TRUE)
 
output <- list(
  "output_lc" =  output_nc_predictors
                  ) 
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))