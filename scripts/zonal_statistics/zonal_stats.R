library(rjson)
library(dplyr)
library(exactextractr)
library(terra)
library(sf)

input <- biab_inputs()

# Load study area polygon
if (!is.null(input$study_area)){
study_area <- st_read(input$study_area_polygon) %>% st_transform(input$crs)
} else {
 bbox <- st_bbox(c(xmin = input$bbox[1], ymin = input$bbox[2], xmax = input$bbox[3], ymax = input$bbox[4]), crs = st_crs(input$crs))
 study_area <- st_as_sfc(bbox)
}

# Load rasters
rasters <- rast(input$rasters)

# Extract summary statistics
zonal_df <- exact_extract(rasters, study_area, input$summary_statistic)

# Make nicer table
library(tidyr)
zonal_df <- pivot_longer(zonal_df, cols=names(zonal_df))
print(zonal_df)
zonal_df <- zonal_df %>% separate(col = name, into = c("layer", "statistic"), sep = "\\.")
print(zonal_df)

stats_path <- file.path(outputFolder, "zonal_stats.csv")
write.csv(zonal_df, stats_path, row.names=F)
biab_output("zonal_stats", stats_path)