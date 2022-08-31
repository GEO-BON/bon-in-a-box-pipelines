

## Install required packages
packages <- c("terra", "rjson", "raster", "dplyr", "ENMeval", "devtools")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

library("devtools")
if (!"stacatalogue" %in% installed.packages()[,"Package"]) devtools::install_github("ReseauBiodiversiteQuebec/stac-catalogue")
if (!"gdalcubes" %in% installed.packages()[,"Package"]) devtools::install_github("appelmar/gdalcubes_R")


## Load required packages

library("terra")
library("rjson")
library("raster")
library("dplyr")
library("gdalcubes")
library("ENMeval")
library("stacatalogue")
#library("devtools")
#install.packages("ENMeval")
#devtools::install_github("ReseauBiodiversiteQuebec/ratlas")
#devtools::install_github("ReseauBiodiversiteQuebec/sdm-pipeline")


## Load functions
source(paste(Sys.getenv("SCRIPT_LOCATION"), "setupDataSdm/funcSetupDataSdm.R", sep = "/"))
source(paste(Sys.getenv("SCRIPT_LOCATION"), "loadPredictors/funcLoadPredictors.R", sep = "/"))
source(paste(Sys.getenv("SCRIPT_LOCATION"), "utils/utils.R", sep = "/"))

## Receiving args
args <- commandArgs(trailingOnly=TRUE)
outputFolder <- args[1] # Arg 1 is always the output folder
cat(args, sep = "\n")


input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)

presence <- read.table(file = input$clean_presence, sep = '\t', header = TRUE) 
background <- read.table(file = input$clean_background, sep = '\t', header = TRUE) 
study_extent <- sf::st_read(input$study_extent)

bbox <- sf::st_bbox(study_extent, crs = input$proj_to)

# layers
layers <- input$layers

predictors <- 
  load_cube(stac_path = "http://io.biodiversite-quebec.ca/stac/",
            limit = 5000, 
            collections = c("chelsa-clim"), 
            layers = input$layers,
            bbox = bbox,
            srs.cube = input$proj_to,
            t0 = "1981-01-01",
            t1 = "1981-01-01",
            spatial.res = input$spatial_res, # in meters
            temporal.res = "P1Y",
            aggregation = "mean",
            resampling = "near") 

predictors <- cube_to_raster(predictors, format = "terra")
predictors <- fast_crop(predictors, study_extent)
names(predictors) <- input$layers

presence_bg_vals <- setup_presence_background(
  presence = presence,
  background = background,
  predictors = predictors,
  partition_type = input$partition_type,
  runs_n = input$runs_n,
  boot_proportion = input$boot_proportion,
  cv_partitions = input$cv_partitions,
  seed=NULL)

output_presence_background <- file.path(outputFolder, "presence_background.tsv")
output_predictors <- file.path(outputFolder, "predictors.tif")

terra::writeRaster(predictors, output_predictors, overwrite = T)
write.table(presence_bg_vals, output_presence_background,
             append = F, row.names = F, col.names = T, sep = "\t")

output <- list("presence_background" =  output_presence_background,
  "predictors" = output_predictors
                  ) 
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))