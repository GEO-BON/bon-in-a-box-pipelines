

## Install required packages
pak::pkg_install(c("terra", "rjson", "raster", "dplyr"))


## Load required packages

library("terra")
library("rjson")
library("raster")
library("dplyr")
## Load functions
source(paste(Sys.getenv("SCRIPT_LOCATION"), "SDM/rangePredictionsFunc.R", sep = "/"))

## Receiving args
args <- commandArgs(trailingOnly=TRUE)
outputFolder <- args[1] # Arg 1 is always the output folder
cat(args, sep = "\n")


input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)


range <- range_predictions(input$predictions)
output_range <- file.path(outputFolder, "range_predictions.tif")

 if(!is.null(output_range)) {
terra::writeRaster(range, output_range, overwrite = T)
 }

output <- list("range_predictions" =  output_range)
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))