

## Install required packages
packages <- c("terra", "rjson", "raster", "stars")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

## Load required packages
library("terra")
library("rjson")
library("raster")
library("stars")


setwd(outputFolder)
# Does this make sense with setwd()? -Dat
input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)

predictors <- terra::rast(input$predictors)
presence <- read.table(file = input$presence, sep = '\t', header = TRUE)

# Get projection
proj = terra::crs(predictors, proj = T)

# Convert to SpatVector
presence <- terra::vect(presence[,c("lon", "lat")], crs = proj)
# Convert to SpatRaster; sum within cells (fun = length)
convertedRaster <- terra::rasterize(presence, predictors, fun = "length")

heatmap <- file.path(outputFolder, "heatmap_output.tif")
writeRaster(convertedRaster, heatmap, overwrite = T)
output <- list("heatmap" =  heatmap) 

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))
