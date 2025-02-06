library(terra)
library(rjson)

input <- biab_inputs()

rasters <- input$rasters

start_year <- toString(input$start_year)
print("printing start year")
print(start_year)
end_year <- toString(input$end_year-1)
print("printing end year")
print(end_year)


first_raster <- rasters[grepl(start_year, rasters)]
print(first_raster)
end_raster <- rasters[grepl(end_year, rasters)]
print(end_raster)

print("Loading phenology data")
print("printing first raster")
load_first_raster <- terra::rast(first_raster)
print(load_first_raster)

print("printing end raster")
load_end_raster <- terra::rast(end_raster)
print(load_end_raster)

num_bands <- nlyr(load_end_raster)
layer_paths <- c()

print(names(load_end_raster))
for (i in 1:num_bands){
    phenology_change <- load_end_raster[[i]]-load_first_raster[[i]]
    phenology_change_path <- file.path(outputFolder, paste0(names(phenology_change), "_difference.tif"))
    out <- writeRaster(phenology_change, phenology_change_path)
    layer_paths[i]<-phenology_change_path
}

biab_output("phenology_change", layer_paths)