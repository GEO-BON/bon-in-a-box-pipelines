library(rjson)
library(sf)
library(terra)
library(dplyr)
library(ggplot2)

# Read inputs
input <- biab_inputs()

# Read in country polygon
dat <- st_read(input$country_polygon)

# Error if polygon is empty
if (nrow(dat)==0){
    biab_error_stop("Country polygon does not exist. Check spelling.")
}

print("Polygon successfully loaded")

# Transform polygon
dat.transformed <- st_transform(dat, crs=input$crs)

# Load array of raster files
rasters <- terra::rast(c(input$rasters, crs=input$crs))

# Crop by polygon
country_vect <- vect(dat.transformed)
rasters.cropped <- mask(rasters, country_vect)

print("Raster cropped by country polygon")

# Calculate change in values between rasters
raster_change <- rasters[[1]]-rasters[[2]]

# specify file path and write output for rasters
raster_change_path<- file.path(outputFolder, "raster_change.tif")
writeRaster(raster_change, raster_change_path, overwrite=TRUE)

biab_output("raster_change", raster_change_path)

# Calculate mean of raster
layer_means <- global(rasters.cropped, fun="mean", na.rm=TRUE)
layer_means$name <- names(rasters.cropped)

# Plot means
means_plot <- ggplot(layer_means, aes(x=name, y=mean)) +
    geom_point()

# Specify file path and write output for plots
means_plot_path <- file.path(outputFolder, "means_plot.png")
ggsave(means_plot_path, means_plot)

biab_output("means_plot", means_plot_path)



























































library(rjson)
library(sf)
library(terra)
library(dplyr)
library(ggplot2)


input <- biab_inputs()

# Read in a shapefile
dat <- st_read(input$country_polygon)

print("shapefile successfully loaded")

# Error for if the shapefile is empty
if (nrow(dat)==0){
    biab_error_stop("Country polygon does not exist")
}

# Transform shapefile
dat.transformed <- dat %>% st_transform(crs=input$crs)

# Load array of raster files
rasters <- terra::rast(c(input$rasters, crs=input$crs))

# Crop by polygon
country_vect <- vect(dat.transformed)

rasters.cropped <- mask(rasters, country_vect)

print("Raster cropped by country polygon")

# Calculate change in values over time
raster_change <- rasters[[1]]-rasters[[2]]

#raster_change <- project(raster_change, "epsg:3857")

# specify file path
raster_change_path <- file.path(outputFolder, "raster_change.tif")
# write file
writeRaster(raster_change, raster_change_path)
# write biab output
biab_output("raster_change", raster_change_path)

# Calculate mean for each layer
layer_means <- global(rasters.cropped, fun="mean", na.rm=TRUE)
layer_means$name <- names(rasters.cropped)


# Plot time series
means_plot <- ggplot(layer_means, aes(x=name, y=mean)) + 
                geom_point()

means_plot_path <- file.path(outputFolder, "means.plot.png")
ggsave(means_plot_path, means_plot)
biab_output("means_plot", means_plot_path)




