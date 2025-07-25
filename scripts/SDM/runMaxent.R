## Load required packages

memtot <- as.numeric(system("awk '/MemTotal/ {print $2}' /proc/meminfo", intern = TRUE)) / 1024^2
memallow <- floor(memtot * 0.9) # 90% of total available memory
print(paste0(memallow, "G of RAM allowed to Java heap space"))
options(java.parameters = paste0("-Xmx", memallow, "g"))

library("terra")
library("rjson")
library("raster")
library("dplyr")
library("ENMeval")

## Load functions
source(paste(Sys.getenv("SCRIPT_LOCATION"), "SDM/runMaxentFunc.R", sep = "/"))
source(paste(Sys.getenv("SCRIPT_LOCATION"), "SDM/sdmUtils.R", sep = "/"))

input <- biab_inputs()
print("Inputs : ")
print(input)

presence_background <- read.table(file = input$presence_background, sep = "\t", header = TRUE, check.names = FALSE)
predictors <- terra::rast(unlist(input$predictors))
mod_tuning <- run_maxent(presence_background,
  with_raster = F, # can be set to F to speed up
  algorithm = "maxent.jar",
  layers = names(predictors),
  predictors = predictors,
  partition_type = input$partition_type,
  n_folds = input$n_folds,
  orientation_block = input$orientation_block,
  factors = NULL,
  # used if partition_type is "randomkfold"
  rm = input$rm,
  fc = input$fc,
  parallel = T,
  updateProgress = T,
  parallelType = "doParallel"
)

res_tuning <- mod_tuning@results
tuned_param <- select_param(res_tuning, method = input$method_select_params, list = T)

# predictors <- raster::stack(predictors)

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
  output_folder = outputFolder
)

sdm_pred <- sdms[["pred_all"]][[1]]
sdm_pred[sdm_pred < 0] <- 0.0001
names(sdm_pred) <- "prediction"
sdm_runs <- sdms[["pred_runs"]]

pred.output <- file.path(outputFolder, "sdm_pred.tif")
runs.output <- paste0(outputFolder, "/sdm_runs_", 1:nlyr(sdm_runs), ".tif")
# runs.output <- file.path(outputFolder, "sdm_runs.tif")
biab_output("sdm_pred", pred.output)

sdm_pred <- project(sdm_pred, crs(input$proj)) ## Temporary fix while maxent transitions to terra
terra::writeRaster(
  x = sdm_pred,
  filename = pred.output,
  filetype = "COG",
  wopt = list(gdal = c("COMPRESS=DEFLATE")),
  overwrite = TRUE
)
for (i in 1:nlyr(sdm_runs)) {
  thisrun <- project(sdm_runs[[i]], crs(input$proj)) ## Temporary fix while maxent transitions to terra
  terra::writeRaster(
    x = thisrun,
    filename = file.path(outputFolder, paste0("/sdm_runs_", i, ".tif")),
    filetype = "COG",
    wopt = list(gdal = c("COMPRESS=DEFLATE")),
    overwrite = TRUE
  )
}

biab_output("sdm_runs", runs.output)
