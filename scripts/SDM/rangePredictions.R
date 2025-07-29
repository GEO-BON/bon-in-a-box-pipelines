## Load required packages

library("terra")
library("rjson")
library("raster")
library("dplyr")
## Load functions
source(paste(Sys.getenv("SCRIPT_LOCATION"), "SDM/rangePredictionsFunc.R", sep = "/"))

input <- biab_inputs()
print("Inputs: ")
print(input)

range <- range_predictions(input$predictions)
output_range <- file.path(outputFolder, "range_predictions.tif")

if (!is.null(output_range)) {
  terra::writeRaster(range, output_range, overwrite = T, gdal = c("COMPRESS=DEFLATE"), filetype = "COG")
}

biab_output("range_predictions", output_range)
