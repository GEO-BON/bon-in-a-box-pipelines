input <- biab_inputs()

raster_for_resampling <- terra::rast(input$raster_1)
raster_2 <- terra::rast(input$raster_2)

resampled_layers <- list()

for (i in 1:terra::nlyr(raster_2)) {
  resampled_layer <- terra::resample(raster_2[[i]], raster_for_resampling[[1]], method = input$resampling)
  resampled_layers[[i]] <- resampled_layer
}
resampled_layers <- terra::rast(resampled_layers)

print(terra::ext(resampled_layers))
print(terra::ext(raster_for_resampling))

path <- file.path(outputFolder, "rasters.tif")
terra::writeRaster(resampled_layers, path, overwrite = TRUE)

biab_output("resampled_raster", path)