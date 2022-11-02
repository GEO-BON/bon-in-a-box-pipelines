


# Calculating proportion of Protected Areas (polygons) within a raster pixel (e.g., 1000m)

# world database on protected areas (wdpa) source: https://www.protectedplanet.net/en


# Packages

packages <- c("sf", "wdpar", "terra", "exactextractr", "dplyr", "raster")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

# libraries
library("rjson")
library("sf")
library("wdpar")
library("terra")
library("exactextractr")
library("dplyr")
library("raster")
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

source("/scripts/protected Areas/ProtectedAreasPropFunc.R")
source("/scripts/data/loadObservationsFunc.R")



# Pb if buffer set to 0, transformed into empty string. Warn JM about this
if (input$buffer_box == "...") buffer_box <- 0

# Case 1: we create an extent from a set of observations
if (input$use_obs) {
  obs <- load_observations(species = input$species,
                           limit = input$species_limit,
                           database = "gbif",
                           year_start = input$species_year_start,
                           year_end = input$species_year_end) 
  
  # Reproject the obs to the data cube projection
  obs_pts <-
    stacatalogue::project_coords(obs,
                                 lon = "decimal_longitude",
                                 lat = "decimal_latitude",
                                 proj_from = "+proj=longlat +datum=WGS84",
                                 proj_to = input$srs_cube)
  
  # Create the extent (data cube projection)
  bbox <- stacatalogue::points_to_bbox(obs_pts, buffer = buffer_box)
  
  
  # Case 2: we use a shapefile
} else if (!is.null(input$shapefile_path)) {
  obs <- NULL
  shp <- sf::st_read(input$shapefile_path)
  bbox <- stacatalogue::shp_to_bbox(shp,
                                    proj_to = input$srs_cube)
  
  # Case 3: we use a vector
} else if (!is.null(input$bbox)) {
  
  obs <- NULL
  bbox <- st_bbox(c(xmin = bbox[1], xmax = bbox[2], 
                    ymax = bbox[3], ymin = bbox[4]), crs = st_crs(input$srs_cube))
} 



print("Calculating proprotion of protected areas within a pixel size...")

tif <- protected_areas(country = "Canada",
                       bbox = c(-79.76281,  44.99137, -57.10549, 62.58277),
                       crs = "EPSG:6623",
                       pixel_size = 1000,
                       habitat_type = c("terrestrial")
)



output_tif <- file.path(outputFolder, "Protected_areas_prop.tif")
raster::writeRaster(x = tif,
                    output_tif,
                    overwrite = TRUE)


print("PAs propotion saved.")



# Outputing result to JSON
output <- list("output_tif" = output_tif)

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))



