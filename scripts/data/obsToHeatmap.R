## Load required packages
library("terra")
library("rjson")
library("raster")
library("stars")

input <- biab_inputs()
print("Inputs: ")
print(input)

predictors <- terra::rast(input$predictors)
presence <- read.table(file = input$presence, sep = "\t", header = TRUE)

# Get projection
proj <- terra::crs(predictors, proj = T)

# Convert to SpatVector
presence <- terra::vect(presence[, c("lon", "lat")], crs = proj)
# Convert to SpatRaster; sum within cells (fun = length)
convertedRaster <- terra::rasterize(presence, predictors, fun = "length")

heatmap <- file.path(outputFolder, "heatmap_output.tif")
writeRaster(convertedRaster, heatmap, overwrite = TRUE)

biab_output("heatmap", heatmap)
