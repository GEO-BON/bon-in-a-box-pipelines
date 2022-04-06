

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
source("/scripts/utils/utils.R")
source("/scripts/utils/predictors_func.R")

## Receiving args
args <- commandArgs(trailingOnly=TRUE)
outputFolder <- args[1] # Arg 1 is always the output folder
cat(args, sep = "\n")


input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)


clean_presence <- read.table(file = input$clean_presence, sep = '\t', header = TRUE) 
clean_background <- read.table(file = input$clean_background, sep = '\t', header = TRUE) 
study_extent <- sf::st_read(input$study_extent)

bbox <- sf::st_bbox(study_extent, crs = input$proj_to)

predictors_nc <- 
  load_cube(stac_path = "http://io.biodiversite-quebec.ca/stac/",
            limit = 5000, 
            collections = c("chelsa-clim"), 
            use.obs = F,
            buffer.box = 0,
            layers = input$layers,
            bbox = bbox,
            srs.cube = input$proj_to,
            t0 = "1981-01-01",
            t1 = "1981-01-01",
            spatial.res = 1000, # in meters
            temporal.res = "P1Y",
            aggregation = "mean",
            resampling = "near") 



predictors_nc <- cube_to_raster(predictors_nc, format = "terra")
predictors_nc <- fast_crop(predictors_nc, study_extent)
presence.vals <- add_predictors(clean_presence, lon = "lon", lat = "lat", predictors = predictors_nc) %>% dplyr::mutate(pa = 1)
bg.vals <- add_predictors(clean_background, lon = "lon", lat = "lat", predictors = predictors_nc) %>% dplyr::mutate(pa = 0)
presence.bg.vals <- dplyr::bind_rows(presence.vals, bg.vals)

partition_type <-  c("block")
mod_tuning <- run_maxent(presence.bg.vals, 
                         with_raster = F, # can be set to F to speed up
                         algorithm = "maxent.jar",
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

output_pred <- file.path(outputFolder, "prediction.tif")
output_eval <- file.path(outputFolder, "eval.tsv")

write.table(res_tuning, output_eval,
             append = F, row.names = F, col.names = T, sep = "\t")

predictors_nc <- raster::stack(predictors_nc)

pred_pres <- predict_maxent(mod_tuning,
                            algorithm = "maxent.jar",
                            param = tuned_param,
                            predictors = predictors_nc, 
                           mask = NULL,
                           type = "cloglog")
raster::writeRaster(pred_pres, output_pred, overwrite = T)

  output <- list("prediction_map" =  output_pred,
                 "output_eval" =  output_eval
                  ) 
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))