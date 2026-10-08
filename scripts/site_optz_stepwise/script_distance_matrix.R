library(rjson)
input <- biab_inputs()

locations_path <- input$locations_csv
# Retain compatibility with saved runs while using one external example file.
if (identical(locations_path, "Sample Peru")) {
  locations_path <- "/scripts/site_optz_stepwise/site_optz_stepwise_EXAMPLE_samp_loc_peru.csv"
}
if (!is.character(locations_path) || length(locations_path) != 1L ||
    is.na(locations_path) || !nzchar(locations_path) || !file.exists(locations_path)) {
  biab_error_stop("Provide a valid sampling CSV path, such as /userdata/sampling_sites.csv.")
}
locs_df <- tryCatch(read.csv(locations_path), error = function(e) {
  biab_error_stop(paste("Cannot read sampling CSV:", conditionMessage(e)))
})
required_columns <- c("lon", "lat", "vini")
missing_columns <- setdiff(required_columns, names(locs_df))
if (length(missing_columns) > 0L) {
  biab_error_stop(paste("Sampling CSV is missing columns:", paste(missing_columns, collapse = ", ")))
}
if (nrow(locs_df) < 2L ||
    !all(vapply(locs_df[required_columns], is.numeric, logical(1))) ||
    !all(is.finite(as.matrix(locs_df[required_columns])))) {
  biab_error_stop("Provide at least two sites with finite numeric lon, lat, and vini values.")
}
if (any(abs(locs_df$lon) > 180) || any(abs(locs_df$lat) > 90)) {
  biab_error_stop("Coordinates must be longitude and latitude in WGS84 decimal degrees.")
}
if (!all(locs_df$vini %in% c(0, 1))) {
  biab_error_stop("vini must be 1 for current sites or 0 for demand points.")
}
if (!any(locs_df$vini == 1) || !any(locs_df$vini == 0)) {
  biab_error_stop("Provide both current sites (vini = 1) and demand points (vini = 0).")
}

# CSV coordinates always use WGS84, independently of the raster CRS.
locs_wgs84 <- terra::vect(locs_df, geom = c("lon", "lat"), crs = "EPSG:4326")
predictors <- terra::rast(input$rasters)
locs <- terra::project(locs_wgs84, predictors)
values_occ <- terra::extract(terra::scale(predictors), locs)
values_occ$ID <- NULL
if (!all(is.finite(as.matrix(values_occ)))) {
  biab_error_stop("All sites need valid environmental values. Check raster coverage, missing cells, and constant predictors.")
}

# Register each matrix immediately so later failures retain partial outputs.
env_matrix <- as.matrix(stats::dist(values_occ, method = "euclidean"))
env_matrix_path <- file.path(outputFolder, "env_matrix.csv")
write.csv(env_matrix, env_matrix_path, row.names = FALSE)
biab_output("env_matrix", env_matrix_path)

# Ellipsoidal geodesic distances in metres; classification is not a coordinate.
dist_matrix <- as.matrix(terra::distance(locs_wgs84, method = "geo"))
dist_matrix_path <- file.path(outputFolder, "dist_matrix.csv")
write.csv(dist_matrix, dist_matrix_path, row.names = FALSE)
biab_output("dist_matrix", dist_matrix_path)

# Preserve the existing element-wise combination of the two measures.
mdist <- env_matrix * dist_matrix
mdist_path <- file.path(outputFolder, "mdist.csv")
write.csv(mdist, mdist_path, row.names = FALSE)
biab_output("mdist", mdist_path)
