library(terra)
library(rjson)
library(dplyr)

input <- biab_inputs()

# load phenology rasters
#rasters <- terra::rast(c(input$rasters))
#print(names(rasters))
rasters <- input$rasters
print(rasters)

start_date <- toString(input$start_date)
print(start_date)
end_date <- toString(as.numeric(input$end_date)-1)
print(end_date)

first_raster <- rasters[grepl(start_date, rasters)]
print("printing first raster")
print(first_raster)
end_raster <- rasters[grepl(end_date, rasters)]
print("printing end raster")
print(end_raster)

lfirst_raster <- terra::rast(first_raster)
lend_raster <- terra::rast(end_raster)
print("printing 1")
print(lfirst_raster)
print("printing 2")
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

print(layer_paths)

#phenology_change_path <- file.path(outputFolder, "phenology_change.tif")
#writeRaster(x=phenology_change, filename=phenology_change_path)

biab_output("phenology_change", layer_paths)