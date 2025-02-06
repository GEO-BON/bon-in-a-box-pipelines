library(terra)
library(rjson)

input <- biab_inputs()

rasters <- input$rasters

start_date <- toString(input$start_date)

end_date <- toString(as.numeric(input$end_date)-1)


first_raster <- rasters[grepl(start_date, rasters)]
end_raster <- rasters[grepl(end_date, rasters)]

print("Loading phenology data")
print("printing first raster")
lfirst_raster <- terra::rast(first_raster)
print(lfirst_raster)
print("printing end raster")
lend_raster <- terra::rast(end_raster)
print(lend_raster)

num_bands <- nlyr(lend_raster)
layer_paths <- c()

print(names(lend_raster))
for (i in 1:num_bands){
    phenology_change <- lend_raster[[i]]-lfirst_raster[[i]]
    phenology_change_path <- file.path(outputFolder, paste0(names(phenology_change), "_difference.tif"))
    out <- writeRaster(phenology_change, phenology_change_path)
    layer_paths[i]<-phenology_change_path
}

biab_output("phenology_change", layer_paths)