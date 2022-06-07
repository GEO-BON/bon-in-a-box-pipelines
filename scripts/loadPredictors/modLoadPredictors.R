

## Install required packages
packages <- c("terra", "rjson", "raster", "dplyr", "CoordinateCleaner", "lubridate")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

## Load required packages

#install.packages("gdalcubes")
library("terra")
library("rjson")
library("raster")
library("dplyr")
library("gdalcubes")


## Load functions
source(paste(Sys.getenv("SCRIPT_LOCATION"), "stacCatalogue/stac_functions.R", sep = "/"))
source(paste(Sys.getenv("SCRIPT_LOCATION"), "loadPredictors/funcLoadPredictors.R", sep = "/"))

## Receiving args
args <- commandArgs(trailingOnly=TRUE)
outputFolder <- args[1] # Arg 1 is always the output folder
cat(args, sep = "\n")


input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)

if(!is.null(input$presence)) {

presence <- read.table(file = input$presence, sep = '\t', header = TRUE) 

presence <- CoordinateCleaner::cc_val(presence, lon = "decimalLongitude", 
                                 lat = "decimalLatitude", verbose = T, value = "clean")

presence <- CoordinateCleaner::cc_zero(presence, lon = "decimalLongitude", 
                                        lat = "decimalLatitude", buffer = 0.5, 
                                        verbose = T, value = "clean")

presence <- create_projection(presence, lon = "decimalLongitude", lat = "decimalLatitude", 
proj_from = "+proj=longlat +datum=WGS84", proj_to = input$proj_to, new_lon = "lon", new_lat = "lat") 

bbox <- points_to_bbox(dplyr::select(presence, lon, lat), proj_from = input$proj_to, buffer = input$obs_buffer)

} else {
bbox <- input$bbox  
}

if(is.null(input$nb_sample)) {
  sample <- FALSE 
  } else {
    sample <- TRUE
  }


layers <- strsplit(gsub("[^[:alnum:] ]", " ", input$layers), " +")

if (length(layers) == 1) {
  layers <- layers[[1]][layers[[1]]!=""]
} else {
layers <- input$layers
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
            resampling = "near",
            buffer.box = NULL),
                          
                           subset_layers = layers,
                           remove_collinear = F,
                           method = input$method,
                           method_cor_vif = input$method_cor_vif,
                           new_proj = input$proj_to,
                           mask = bbox,
                           sample = sample,
                           nb_points = input$nb_sample,
                           cutoff_cor = input$cutoff_cor,
                           cutoff_vif = input$cutoff_vif,
                           export = F,
                           ouput_dir = getwd(),
                           as.list = T)


output_nc_predictors <- file.path(outputFolder, "nc_predictors.tsv")


  output <- list(
                  "nc_predictors" = predictors_nc
                  ) 
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))