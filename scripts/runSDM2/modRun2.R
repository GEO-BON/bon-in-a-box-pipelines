

## Install required packages

## Load required packages
options(java.parameters = "-Xmx8000m")
library("terra")
library("rjson")
library("raster")
library("dplyr")
library("gdalcubes")
library("ENMeval")


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


clean_presence <- read.table(file = input$clean_presence, sep = '\t', header = TRUE) 
clean_background <- read.table(file = input$clean_background, sep = '\t', header = TRUE) 
mask <- sf::st_read(input$mask)

predictors_nc <- load_predictors(source = "from_tif",
                            predictors_dir = input$tif_folder,
                            subset_layers = input$layers,
                            remove_collinear = F,
                            method = "vif.cor",
                            method_cor_vif = NULL,
                            new_proj = NULL,
                            mask = mask,
                            sample = TRUE,
                            nb_points = 5000,
                            cutoff_cor = 0.7,
                            cutoff_vif = 3,
                            export = TRUE,
                            ouput_dir = NULL,
                            as.list = F)

clean_presence_vals <- dplyr::bind_cols(clean_presence,
  terra::extract(predictors_nc, 
                          dplyr::select(clean_presence, "lon", "lat")) %>% dplyr::select(-ID)  %>%
                          data.frame()) 

clean_bg_vals <- dplyr::bind_cols(clean_background,
  terra::extract(predictors_nc, 
                          dplyr::select(clean_background, "lon", "lat")) %>% dplyr::select(-ID)  %>%
                          data.frame()) 

presence.bg.vals <- dplyr::bind_rows(clean_presence_vals %>% dplyr::mutate(pa = 1),
 clean_bg_vals %>% dplyr::mutate(pa = 0))

partition_type <-  c("none")
mod_tuning <- run_maxent(presence.bg.vals, 
                         with_raster = F, # can be set to F to speed up
                         algorithm = "maxent.jar",
                         predictors = NULL,
                         partition_type = partition_type,
                         factors = NULL,
                         nfolds = 5, #used if partition_type is "randomkfold"
                         rm = 1, 
                         fc = "LQ",
                         parallel = T,
                         updateProgress = T,
                         parallelType = "doParallel")

res_tuning <- mod_tuning@results

output_pred <- file.path(outputFolder, "prediction.tif")
output_eval <- file.path(outputFolder, "eval.tsv")

write.table(res_tuning, output_eval,
             append = F, row.names = F, col.names = T, sep = "\t")

#predictors_nc <- raster::stack(predictors_nc)

pred_pres <- predict_maxent(mod_tuning,
                            algorithm = "maxent.jar",
                            param = "fc.LQ_rm.1",
                            predictors = predictors_nc,
                            type = "cloglog")

raster::writeRaster(pred_pres, output_pred, overwrite = T)

  output <- list("prediction_map" =  output_pred,
                 "output_eval" =  output_eval
                  ) 
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))