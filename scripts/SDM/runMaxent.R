

## Install required packages

## Load required packages

library("terra")
library("rjson")
library("raster")
library("dplyr")
library("gdalcubes")
library("ENMeval")
library("devtools")
if (!"stacatalogue" %in% installed.packages()[,"Package"]) devtools::install_github("ReseauBiodiversiteQuebec/stac-catalogue")
if (!"gdalcubes" %in% installed.packages()[,"Package"]) devtools::install_github("appelmar/gdalcubes_R")
library("stacatalogue")


## Load functions
source(paste(Sys.getenv("SCRIPT_LOCATION"), "SDM/runMaxentFunc.R", sep = "/"))
source(paste(Sys.getenv("SCRIPT_LOCATION"), "SDM/sdmUtils.R", sep = "/"))
## Receiving args
args <- commandArgs(trailingOnly=TRUE)
outputFolder <- args[1] # Arg 1 is always the output folder
cat(args, sep = "\n")


input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)


presence_background <- read.table(file = input$presence_background, sep = '\t', header = TRUE) 
predictors <- terra::rast(unlist(input$predictors))
mod_tuning <- run_maxent(presence_background, 
                         with_raster = F, # can be set to F to speed up
                         algorithm = "maxent.jar",
                         layers = names(predictors),
                         predictors = NULL,
                         partition_type = input$partition_type,
                         nfolds = input$nfolds,
                         orientation_block = input$orientation_block,
                         factors = NULL,
                         #used if partition_type is "randomkfold"
                         rm = input$rm, 
                         fc = input$fc,
                         parallel = T,
                         updateProgress = T,
                         parallelType = "doParallel")

res_tuning <- mod_tuning@results
tuned_param <- select_param(res_tuning, method = input$method_select_params, list = T)

predictors <- raster::stack(predictors)

sdms <- predict_maxent(presence_background, 
  algorithm = "maxent.jar", 
                           predictors = predictors,  
                           fc = tuned_param[[1]],                         
                           rm = tuned_param[[2]], 
                           type = "cloglog",
                           mask = NULL,
                           parallel = T,
                           updateProgress = T,
                           parallelType = "doParallel",
                           factors = c(),
                           output_folder = outputFolder)

sdm_pred <- sdms[["pred_all"]][[1]]
sdm_pred[sdm_pred < 0] <- 0.0001
names(sdm_pred) <- "prediction"
sdm_runs <- sdms[["pred_runs"]]

pred.output <- file.path(outputFolder, "sdm_pred.tif")
runs.output <- file.path(outputFolder, "sdm_runs.tif")

raster::writeRaster(x = sdm_pred,
                          filename = pred.output,
                          format='COG',
                          options=c("COMPRESS=DEFLATE"),
                          overwrite = TRUE)
 #terra::writeRaster(x = sdm_runs,
  #                        filename = runs.output,
  #                        format='COG',
  #                        options=c("COMPRESS=DEFLATE"),
  #                        overwrite = TRUE)

output <- list("sdm_pred" = pred.output,
  "sdm_runs" = runs.output) 

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))