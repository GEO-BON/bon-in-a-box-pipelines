

## Install required packages

## Load required packages
#remotes::install_github('cjcarlson/embarcadero')
#devtools::install_local(paste0(Sys.getenv("SCRIPT_LOCATION"), "/embarcadero.zip"))
library("terra")
library("rjson")
library("raster")
library("dplyr")
library(tidyverse)
library(readr)
Sys.setenv("R_REMOTES_NO_ERRORS_FROM_WARNINGS" = "true")
Sys.setenv('R_MAX_VSIZE'=100000000000) 
library("embarcadero")
memory.limit(90000)

## Load functions
source(paste(Sys.getenv("SCRIPT_LOCATION"), "SDM/runBARTFunc.R", sep = "/"))
## Receiving args
args <- commandArgs(trailingOnly=TRUE)
outputFolder <- args[1] # Arg 1 is always the output folder
cat(args, sep = "\n")


input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)


sdm_data <- read.table(file = input$presence_absence, sep = '\t', header = TRUE) 

# Format for bart() function
sdm_data <- sdm_data |> data.frame()
predictors <- terra::rast(input$predictors)
predictors <- terra::aggregate(predictors, fact=input$aggregation_factor)
covars <- names(predictors)

if (input$select_variables) {
  print("Selecting variables...")
  system.time({ 
    covars <- variable.step(
    y.data = sdm_data[,'pa'],
    x.data = sdm_data[, covars],
    iter = 2
  )})
  print(paste0("Variables selected: ", covars))
}

print("Training BART model")
 system.time({ sdm <- bart(y.train = sdm_data[,'pa'],
            x.train = sdm_data[, covars],
            keeptrees = TRUE) })


print("Transforming predictors to data.frame")
df <- terra::as.data.frame(predictors, na.rm = F)


print("Predicting BART")

n_chunks <- nrow(df)%/%100
lst <- split(df, cumsum((1:nrow(df)-1)%%n_chunks==0))
system.time({
pred <- lapply(lst, predict.bart.df, object=sdm, quantiles=c(0.025, 0.975))
pred <- dplyr::bind_rows(pred)

})


pred.r <- pred.uncertainty <- predictors[[1]]
pred.r <- setValues(pred.r, pred$p)
pred.CI <- predictors[[1]]  #posterior mean
pred.CI <- setValues(pred.uncertainty, pred[,3] - pred[,2])   #Credible interval width


output_pred <- file.path(outputFolder, "sdm_pred.tif")
raster::writeRaster(x = pred.r,
                          filename = output_pred,
                          format='COG',
                          options=c("COMPRESS=DEFLATE"),
                          overwrite = TRUE)

output_uncertainty <- file.path(outputFolder, "sdm_CI.tif")
raster::writeRaster(x = pred.CI,
                          output_uncertainty,
                          format='COG',
                          options=c("COMPRESS=DEFLATE"),
                          overwrite = TRUE)
 
output <- list("sdm_pred" = output_pred,
  "sdm_uncertainty" =  output_uncertainty
                  ) 

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))