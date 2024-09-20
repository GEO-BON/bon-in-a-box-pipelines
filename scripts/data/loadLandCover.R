

## Install required packages

library("devtools")
if (!"stacatalogue" %in% installed.packages()[,"Package"]) devtools::install_github("ReseauBiodiversiteQuebec/stac-catalogue")

packages <- c("terra", "rjson", "raster", "dplyr", "CoordinateCleaner", "lubridate", "rgdal", "remotes")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

library("remotes")
if (!"gdalcubes_R" %in% installed.packages()[,"Package"]) devtools::install_github("ReseauBiodiversiteQuebec/stac-catalogue")


## Load required packages
library("terra")
library("rjson")
library("raster")
library("dplyr")
library("stacatalogue")
library("gdalcubes")
library("RCurl")
options(timeout = max(60000000, getOption("timeout")))

setwd(outputFolder)

input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)


# Tranform the vector to a bbox object

bbox <- sf::st_bbox(c(xmin = input$bbox[1], ymin = input$bbox[2], 
                  xmax = input$bbox[3], ymax = input$bbox[4]), crs = sf::st_crs(input$srs_cube))


n_year <- as.integer(substr(input$t1, 1, 4)) - as.integer(substr(input$t0, 1, 4)) + 1 
temporal_res <- paste0("P", n_year, "Y")

if (input$stac_source == "IO") {
  lc_raster <- stacatalogue::load_prop_values(stac_path = "https://stac.geobon.org/",
                                collections = input$collections, 
                              bbox = bbox,
                               srs.cube = input$srs_cube,
                               limit = 5000,
                                t0 = input$t0,
                                t1 = input$t1,
                                spatial.res = input$spatial_res, # in meters
                                prop = input$prop,
                                prop.res = input$prop_res,
                                select_values = input$select_values,
                                temporal.res =  temporal_res)
  } else if (input$stac_source == "PC") {
  lc_raster <- stacatalogue::load_prop_values_pc(stac_path =  "https://planetarycomputer.microsoft.com/api/stac/v1/",
                                collections = input$collections, 
                              bbox = bbox,
                               srs.cube = input$srs_cube,
                                t0 = input$t0,
                                t1 = input$t1,
                                limit = 5000,
                                spatial.res = input$spatial_res, # in meters
                                prop = input$prop,
                                prop.res = input$prop_res,
                                select_values = input$select_values,
                                temporal.res =  temporal_res)
}



for(i in 1:length(names(lc_raster))){
  raster::writeRaster(x = lc_raster[[i]],
                      paste0(outputFolder, "/", names(lc_raster[[i]]), ".tif"),
                      format='COG',
                      options=c("COMPRESS=DEFLATE"),
                      overwrite = TRUE)
}



lc_classes <- list.files(outputFolder, pattern="*.tif$", full.names = T)

output <- list("output_tif" = lc_classes)
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))

