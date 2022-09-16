

## Install required packages
pak::pkg_install(c("terra", "rjson", "raster", "dplyr", "CoordinateCleaner", "lubridate", "rgdal", "remotes"))

library("devtools")
pak::pkg_install(c("RCurl", "stars")) # appelmar/gdalcubes_R dependencies
if (!"gdalcubes" %in% installed.packages()[,"Package"]) devtools::install_github("appelmar/gdalcubes_R")


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


# Case 1: we create an extent from a set of observations
if (input$use_obs) {
obs <- read.table(file = input$bbox_obs, sep = '\t', header = TRUE) 

obs <- CoordinateCleaner::cc_val(obs, lon = "decimalLongitude", 
                                 lat = "decimalLatitude", verbose = T, value = "clean")

obs <- CoordinateCleaner::cc_zero(obs, lon = "decimalLongitude", 
                                        lat = "decimalLatitude", buffer = 0.5, 
                                        verbose = T, value = "clean")


# Reproject the obs to the data cube projection
obs_pts <-
          stacatalogue::project_coords(obs,
                         lon = "decimalLongitude",
                         lat = "decimalLatitude",
                         proj_from = "+proj=longlat +datum=WGS84",
                         proj_to = input$proj_to)

# Create the extent (data cube projection)
bbox <- stacatalogue::points_to_bbox(obs_pts, buffer = input$bbox_buffer)
print(bbox)

# Case 2: we use a shapefile
} else if (!is.null(input$bbox_shapefile_path)) {
    shp <- sf::st_read(input$bbox_shapefile_path)
    bbox <- stacatalogue::shp_to_bbox(shp,
        proj_to = input$proj_to, buffer = input$bbox_buffer)

# Case 3: we use a vector
} else if (!is.null(input$bbox_coordinates)) {
bbox <- st_bbox(c(xmin = bbox_coordinates[1], xmax = bbox_coordinates[2], 
            ymax = bbox_coordinates[3], ymin = bbox_coordinates[4]), crs = st_crs(input$proj_to))
    } 


n_year <- as.integer(substr(input$t1, 1, 4)) - as.integer(substr(input$t0, 1, 4)) + 1 
temporal_res <- paste0("P", n_year, "Y")

if (input$stac_source == "IO") {
  lc_raster <- stacatalogue::load_prop_values(stac_path = "https://io.biodiversite-quebec.ca/stac/",
                                collections = c("esacci-lc"), 
                              bbox = bbox,
                               srs.cube = input$proj_to,
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
                               srs.cube = input$proj_to,
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
                          overwrite = TRUE)
 
output <- list(
  "output_lc" =  output_nc_predictors
                  ) 
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))