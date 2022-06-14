

# Install required packages

packages <- c("rstac", "tibble", "sp", "sf", "rgdal",  "lubridate", "dplyr",
              "rgbif", "tidyr", "stars", "raster", "terra", "rjson", "RCurl")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)


#library(devtools)
#devtools::install_github("appelmar/gdalcubes_R")
#library(remotes)
#devtools::install_github("https://github.com/appelmar/gdalcubes_R")
devtools::install_github("https://github.com/ReseauBiodiversiteQuebec/stac-catalogue/")


## Load required packages
library("rjson")
library("gdalcubes")
library("rstac")
library("tibble")
library("sp")
library("rgdal")
library("lubridate")
library("RCurl")
library("sf")
library("dplyr")
library("rgbif")
library("tidyr")
library("stars")
library("ggplot2")
library("raster")
library("terra")
options(timeout = max(60000000, getOption("timeout")))


## Receiving args
args <- commandArgs(trailingOnly=TRUE)
outputFolder <- args[1] # Arg 1 is always the output folder
cat(args, sep = "\n")

setwd(outputFolder)
print("output:")
print(outputFolder)
input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)


# Load functions

source("/scripts/ClimateMetrics/funcClimateMetrics.R")
source("/scripts/loadObservations/funcLoadObservations.R")


# Pb if buffer set to 0, transformed into empty string. Warn JM about this
if (input$buffer.box == "...") buffer.box <- 0

# Case 1: we create an extent from a set of observations
if (input$use.obs) {
    obs <- load_observations(species = input$species,
        limit = input$limit,
        database = "gbif",
        year_start = input$species_year_start,
        year_end = input$species_year_end) 

# Reproject the obs to the data cube projection
obs_pts <-
          stacatalogue::project_coords(obs,
                         lon = "decimal_longitude",
                         lat = "decimal_latitude",
                         proj_from = "+proj=longlat +datum=WGS84",
                         proj_to = input$srs.cube)

# Create the extent (data cube projection)
bbox <- stacatalogue::points_to_bbox(obs_pts, buffer = buffer.box)


# Case 2: we use a shapefile
} else if (!is.null(input$shapefile_path)) {
    obs <- NULL
    shp <- sf::st_read(input$shapefile_path)
    bbox <- stacatalogue::shp_to_bbox(shp,
        proj_to = input$srs.cube)

# Case 3: we use a vector
} else if (!is.null(input$bbox)) {

obs <- NULL
bbox <- st_bbox(c(xmin = bbox[1], xmax = bbox[2], 
            ymax = bbox[3], ymin = bbox[4]), crs = st_crs(input$srs.cube))
    } 

print("Loading current climate...")
cube_current <- stacatalogue::load_cube(collections = 'chelsa-monthly', 
                          bbox = bbox,
                          t0 = input$t0,
                          t1 = input$t1,
                          limit = 5000,
                          variable = "tas",
                          spatial.res = input$spatial.res, # in meters
                          temporal.res = input$temporal.res, # see number of years t0 to t1
                          aggregation = input$aggregation,
                          resampling = "bilinear"
                         )
print("Loading current climate loaded.")

print("Loading future climate...")
cube_future <- stacatalogue::load_cube_projection(collections = 'chelsa-clim-proj',            
                          bbox = bbox,
                          limit = 5000,
                          srs.cube = input$srs.cube,
                         rcp = input$rcp, #ssp126, ssp370, ssp585
                          time.span =input$time.span, #"2011-2040", 2041-2070 or 2071-2100
                          variable = "bio1",
                        spatial.res = input$spatial.res,# in meters
                           temporal.res = "P1Y", 
                           aggregation = input$aggregation,
                           resampling = "bilinear"
  
)

print("Future climate loaded.")


print("Calculating metrics...")
tif <- climate_metrics(cube_current,
                          cube_future,
                          metric=input$metric,
                           t_match = input$tmatch,
                          movingWindow = input$movingWindow
                          )

output_tif <- file.path(outputFolder, paste0(input$metric, ".tif"))
raster::writeRaster(x = tif,
                          output_tif,
                          overwrite = TRUE)

print("Metrics saved.")

# Outputing result to JSON
output <- list("output_tif" = output_tif,
               "metric" = input$metric)

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))




