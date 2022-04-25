

## Install required packages

## Load required packages

library("terra")
library("rjson")
library("raster")
library("dplyr")
library("gdalcubes")
library("ENMeval")
#library("devtools")
#install.packages("ENMeval")
#devtools::install_github("ReseauBiodiversiteQuebec/ratlas")
#devtools::install_github("ReseauBiodiversiteQuebec/sdm-pipeline")


## Load functions
source(paste(Sys.getenv("SCRIPT_LOCATION"), "runSDM/funcRunSDM.R", sep = "/"))
source(paste(Sys.getenv("SCRIPT_LOCATION"), "stacCatalogue/stac_functions.R", sep = "/"))
source(paste(Sys.getenv("SCRIPT_LOCATION"), "loadPredictors/funcLoadPredictors.R", sep = "/"))
source(paste(Sys.getenv("SCRIPT_LOCATION"), "utils/utils.R", sep = "/"))
## Receiving args
args <- commandArgs(trailingOnly=TRUE)
outputFolder <- args[1] # Arg 1 is always the output folder
cat(args, sep = "\n")


input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)


presence_background <- read.table(file = input$presence_background, sep = '\t', header = TRUE) 
predictors <- terra::rast(input$predictors)

partition_type <-  c("block")
mod_tuning <- run_maxent(presence_background, 
                         with_raster = F, # can be set to F to speed up
                         algorithm = "maxent.jar",
                         layers = names(predictors),
                         predictors = NULL,
                         partition_type = partition_type,
                         factors = NULL,
                         nfolds = 5, #used if partition_type is "randomkfold"
                         rm = 1, 
                         fc = "L",
                         parallel = T,
                         updateProgress = T,
                         parallelType = "doParallel")

res_tuning <- mod_tuning@results
tuned_param <- select_param(res_tuning, method = "p10", list = F)



predictors <- raster::stack(predictors)


pred_runs <- predict_maxent_2(presence_background, 
  algorithm = "maxent.jar", 
                           predictors = predictors,
                           layers = names(predictors),
                           rm = 1, 
                           fc = "L",
                           type = "cloglog",
                           mask = NULL,
                           parallel = T,
                           updateProgress = T,
                           uncertainty = T,
                           parallelType = "doParallel",
                           factors = c(),
                           output_folder = outputFolder)


output_runs <- file.path(outputFolder, "pred_runs.tif")
raster::writeRaster(x = pred_runs,
                          filename = output_runs,
                          overwrite = TRUE)


uncertainty <- do_uncertainty(output_runs)  

output_uncertainty <- file.path(outputFolder, "uncertainty.tif")
raster::writeRaster(x = uncertainty,
                          output_uncertainty,
                          overwrite = TRUE)
 
output <- list("pred_runs" = output_runs,
  "uncertainty" =  output_uncertainty
                  ) 

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))