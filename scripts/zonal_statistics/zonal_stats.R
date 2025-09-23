library(rjson)
library(dplyr)
library(exactextractr)
library(terra)
library(sf)
library(tidyr)

input <- biab_inputs()

# Load study area polygon
if (!is.null(input$study_area)){
study_area <- st_read(input$study_area_polygon) %>% st_transform(input$crs)
} else {
 bbox <- st_bbox(c(xmin = input$bbox[1], ymin = input$bbox[2], xmax = input$bbox[3], ymax = input$bbox[4]))
 bbox <- st_transform(bbox, input$crs)
 study_area <- st_as_sfc(bbox)
}

# Load rasters
rasters <- rast(input$rasters) %>% project(input$crs)

# Assign layer names based on the file names
names(rasters) <- tools::file_path_sans_ext(basename(input$rasters))

print(rasters)

zonal_list <- list()
# Extract summary statistics
for (i in 1:length(input$summary_statistic)){
zonal_result <- exact_extract(rasters, study_area, input$summary_statistic[i]) # calculate statistic

# Make nicer table
zonal_result <- pivot_longer(zonal_result, cols=names(zonal_result)) %>% separate(col = name, into = c("statistic", "layer"), sep = "\\.")

zonal_list[[i]] <- zonal_result # put all into a list
}

zonal_df <- bind_rows(zonal_list)
zonal_df <- pivot_wider(zonal_df, names_from="statistic", values_from="value")


stats_path <- file.path(outputFolder, "zonal_stats.csv")
write.csv(zonal_df, stats_path, row.names=F)
biab_output("zonal_stats", stats_path)