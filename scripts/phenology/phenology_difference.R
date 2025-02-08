library(terra)
library(rjson)
library(dplyr)
library(tidyr)
library(ggplot2)

input <- biab_inputs()

rasters <- input$rasters

start_year <- toString(input$start_year)
print("printing start year")
print(start_year)
end_year <- toString(as.integer(input$end_year)-1)
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

# Load summary data
summary.dat <- read.csv(input$timeseries)
num.col <- ncol(summary.dat)

summary.dat$date = format(as.POSIXct(summary.dat$date,format='%Y-%m-%dT00:00:00.000Z'),format='%Y-%m-%d')

# Pivot
summary.dat.long <- summary.dat %>% pivot_longer(cols=names(summary.dat[,c(3:num.col)]), names_to = "band", values_to = "summary")
print("summary.dat.long:")
print(summary.dat.long)
# Plot
phenology_change_plot <- ggplot(summary.dat.long, aes(x = date, y = summary)) +
    geom_col(fill='#1d7368') +
    facet_wrap(~band, ncol = 1, scales = "free_y")

phenology_change_plot_path <- file.path(outputFolder, "phenology_change_plot.png")
ggsave(phenology_change_plot_path, phenology_change_plot)
biab_output("phenology_change_plot", phenology_change_plot_path)