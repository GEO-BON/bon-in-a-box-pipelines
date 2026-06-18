# Load inputs
input <- biab_inputs()

SDM_map <- terra::rast(input$raster)
print(SDM_map)
threshold <- input$threshold

# Input validation
if (threshold < 0 && threshold > 1) {
  biab_error_stop("Threshold value must between 0 and 1")
}

if (is.null(SDM_map)) {
  biab_error_stop("Input raster is null. Please enter a valid raster.")
}

# Only save values above threshold and turn into a binary raster
SDM_map[SDM_map <= threshold] <- NA
SDM_map[SDM_map > threshold] <- 1

# Output raster
path <- file.path(outputFolder, "SDM_with_threshold.tif")
terra::writeRaster(SDM_map, filename = path, overwrite = TRUE)

biab_output("range_map", path)