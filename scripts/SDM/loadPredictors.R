

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
extent <- sf::st_read(input$extent)
extent <- sf::st_transform(extent, input$proj_to)
bbox <- stacatalogue::shp_to_bbox(extent)


# Case 3: we use a vector
# bbox <- st_bbox(c(xmin = bbox_coordinates[1], xmax = bbox_coordinates[2], 
#             ymax = bbox_coordinates[3], ymin = bbox_coordinates[4]), crs = st_crs(input$proj_to))
 #    } 

if(is.null(input$nb_sample)) {
  sample <- FALSE 
  } else {
    sample <- TRUE
  }


if(length(input$layers) == 0) layers <- NULL else layers <- input$layers

predictors <- load_predictors(source = "cube",
                            cube_args = list(stac_path = "http://io.biodiversite-quebec.ca/stac/",
            limit = 5000, 
            collections = c("chelsa-clim"),     
            t0 = "1981-01-01",
            t1 = "1981-01-01",
            spatial.res = input$spatial_res, # in meters
            temporal.res = "P1Y",
            aggregation = "mean",
            resampling = "near"),
                          
                           subset_layers = layers,
                           remove_collinear = input$remove_collinearity,
                           method = input$method,
                           method_cor_vif = input$method_cor_vif,
                           proj = input$proj_to,
                           bbox = bbox,
                           mask = extent,
                           sample = sample,
                           nb_points = input$nb_sample,
                           cutoff_cor = input$cutoff_cor,
                           cutoff_vif = input$cutoff_vif,
                           export = F,
                           ouput_dir = getwd(),
                           as_list = F)

#output_nc_predictors <- file.path(outputFolder, "nc_predictors.tsv")


#write.table(predictors_nc, output_nc_predictors, 
 #            append = F, row.names = F, col.names = F, sep = "\t")
output_predictors <- file.path(outputFolder, "predictors.tif")

terra::writeRaster(predictors, output_predictors, overwrite = T)
output <- list("predictors" = output_predictors) 
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))