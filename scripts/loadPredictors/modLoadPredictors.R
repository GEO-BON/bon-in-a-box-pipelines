

## Install required packages
packages <- c("terra", "rjson", "raster", "dplyr", "CoordinateCleaner", "lubridate", "rgdal", "remotes")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

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
source(paste(Sys.getenv("SCRIPT_LOCATION"), "loadPredictors/funcLoadPredictors.R", sep = "/"))

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

if(is.null(input$nb_sample)) {
  sample <- FALSE 
  } else {
    sample <- TRUE
  }


predictors_nc <- load_predictors(source = input$source,
  predictors_dir = input$tif_folder,
                            cube_args = list(stac_path = "http://io.biodiversite-quebec.ca/stac/",
            limit = 5000, 
            collections = c("chelsa-clim"),     
            t0 = "1981-01-01",
            t1 = "1981-01-01",
            spatial.res = input$spatial_res, # in meters
            temporal.res = "P1Y",
            aggregation = "mean",
            resampling = "near"),
                          
                           subset_layers = input$layers,
                           remove_collinear = F,
                           method = input$method,
                           method_cor_vif = input$method_cor_vif,
                           proj = input$proj_to,
                           bbox = bbox,
                           sample = sample,
                           nb_points = input$nb_sample,
                           cutoff_cor = input$cutoff_cor,
                           cutoff_vif = input$cutoff_vif,
                           export = F,
                           ouput_dir = getwd(),
                           as_list = T)


output_nc_predictors <- file.path(outputFolder, "nc_predictors.tsv")


write.table(predictors_nc, output_nc_predictors, 
             append = F, row.names = F, col.names = F, sep = "\t")

  output <- list(
                  "nc_predictors" = predictors_nc
                  ) 
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))