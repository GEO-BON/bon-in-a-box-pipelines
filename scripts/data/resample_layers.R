library(terra)

# Load geotiff
predictor <- rast(input$layers)

# Load water mask
water_mask <- rast(input$water_mask)

# resample water mask
water_mask <- resample(water_mask, predictor, method = "near")

water_mask_path <- file.path(outputFolder, "water_mask_resampled.tif")
writeRaster(water_mask, water_mask_path)

biab_output("water_mask_resampled", water_mask_path)