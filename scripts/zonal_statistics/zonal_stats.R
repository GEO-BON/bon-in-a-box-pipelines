library(rjson)
library(dplyr)
library(exactextractr)
library(terra)
library(sf)
library(tidyr)

input <- biab_inputs()
bounding_box <- input$bbox_crs$bbox
crs <- paste0(input$bbox_crs$CRS$authority, ":", input$bbox_crs$CRS$code)

# Load study area polygon
if (!is.null(input$study_area_polygon)) {
  study_area <- st_read(input$study_area_polygon) %>% st_transform(crs)
} else {
  bbox <- st_bbox(c(xmin = bounding_box[1], ymin = bounding_box[2], xmax = bounding_box[3], ymax = bounding_box[4]), crs = st_crs(crs))
  study_area <- st_as_sfc(bbox)
}

# Load rasters
rasters <- rast(input$rasters) %>% project(crs)

# Assign layer names based on the file names
names(rasters) <- tools::file_path_sans_ext(basename(input$rasters))

print(rasters)

zonal_list <- list()
# Extract summary statistics
for (i in 1:length(input$summary_statistic)) {
  # Keep a table and statistic.layer names even for a single raster layer.
  zonal_result <- exact_extract(
    rasters, study_area, input$summary_statistic[i],
    force_df = TRUE, full_colnames = TRUE
  )

  # Make nicer table
  # Each extraction row belongs to a distinct polygon. Keep that identity
  # when widening so multiple protected areas do not become list columns.
  zonal_result$polygon_id <- seq_len(nrow(zonal_result))
  zonal_result <- pivot_longer(zonal_result, cols = -polygon_id) %>% separate(col = name, into = c("statistic", "layer"), sep = "\\.", extra = "merge")

  zonal_list[[i]] <- zonal_result # put all into a list
}

zonal_df <- bind_rows(zonal_list)
zonal_df <- pivot_wider(zonal_df, names_from = "statistic", values_from = "value")

# Include available protected-area identifiers and names for readable reports.
if (inherits(study_area, "sf")) {
  polygon_info <- st_drop_geometry(study_area) %>%
    select(any_of(c("SITE_ID", "SITE_PID", "WDPAID", "WDPA_PID", "NAME", "NAME_ENG")))
  polygon_info$polygon_id <- seq_len(nrow(study_area))
  zonal_df <- left_join(zonal_df, polygon_info, by = "polygon_id")
}


stats_path <- file.path(outputFolder, "zonal_stats.csv")
write.csv(zonal_df, stats_path, row.names = F)
biab_output("zonal_stats", stats_path)
