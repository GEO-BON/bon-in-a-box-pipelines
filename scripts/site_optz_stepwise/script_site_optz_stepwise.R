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

iters <- input$iters
n_demand <- sum(locs_df$vini == 0)
if (!is.numeric(iters) || length(iters) != 1L || !is.finite(iters) ||
    iters < 1 || iters != floor(iters) || iters > n_demand) {
  biab_error_stop(paste("Algorithm Iterations must be a positive integer no greater than", n_demand, "demand points."))
}
mdist <- tryCatch(as.matrix(read.csv(input$mdist)), error = function(e) {
  biab_error_stop(paste("Cannot read joint distance matrix:", conditionMessage(e)))
})
if (!is.numeric(mdist) || !identical(dim(mdist), c(nrow(locs_df), nrow(locs_df))) ||
    !all(is.finite(mdist)) || any(mdist < 0) ||
    any(diag(mdist) != 0) || !isTRUE(all.equal(mdist, t(mdist), check.attributes = FALSE))) {
  biab_error_stop("Joint distance matrix must be finite, nonnegative, symmetric, and match the sampling CSV row order and site count, with a zero diagonal.")
}
print(utils::head(mdist))
# SURDES caps distances at 1 when evaluating coverage. Preserve relative
# distances by scaling the entire joint matrix with one common positive factor.
max_distance <- max(mdist)
if (max_distance == 0) {
  biab_error_stop("Joint distances are all zero. Use distinct sites and informative environmental predictors.")
}
mdist <- mdist / max_distance

if (!requireNamespace("SURDES", quietly = TRUE)) {
  install.packages("SURDES", repos = "http://R-Forge.R-project.org")
}
library(ggplot2)
library(tidyterra)
set.seed(1234)
conditions <- matrix(1, nrow = 1, ncol = nrow(locs_df))
# SURDES 1.0 uses sd() across remaining scores and cannot handle a final
# single candidate. Run competitive steps normally, then add the sole
# remaining demand point deterministically if the user requests all points.
competitive_iters <- min(iters, n_demand - 1L)
if (competitive_iters > 0L) {
  result <- SURDES::alloc(mdist = mdist, vini = locs_df$vini,
                          criteria = "min", conditions = conditions, iter = competitive_iters)
} else {
  result <- list(selmatrix = matrix(numeric(), nrow = 0, ncol = nrow(locs_df)),
                 pmmatrix = matrix(numeric(), nrow = 0, ncol = nrow(locs_df)))
}
if (iters == n_demand) {
  covered <- locs_df$vini == 1 | colSums(result$selmatrix) > 0
  remaining <- which(!covered)
  if (length(remaining) != 1L) {
    biab_error_stop("SURDES did not leave exactly one final demand point. Check for degenerate distances.")
  }
  final_selection <- integer(nrow(locs_df))
  final_selection[remaining] <- 1L
  # Reproduce SURDES's candidate p-median scores for the final iteration.
  nearest <- apply(mdist[, covered, drop = FALSE], 1, min)
  trial <- pmin(mdist, nearest)
  final_scores <- colSums(trial)
  final_scores[rowSums(trial) == 0] <- 0
  result$selmatrix <- rbind(result$selmatrix, final_selection)
  result$pmmatrix <- rbind(result$pmmatrix, final_scores)
}

# SURDES records the point added at each iteration in each selection-matrix row.
selection <- result$selmatrix
if (!identical(dim(selection), c(as.integer(iters), nrow(locs_df))) ||
    !all(is.finite(selection)) || !all(selection %in% c(0, 1)) ||
    any(rowSums(selection) != 1) || any(colSums(selection) > 1) ||
    any(colSums(selection)[locs_df$vini == 1] != 0)) {
  biab_error_stop("SURDES did not return one distinct demand point per iteration. Check the distance matrix for degenerate distances.")
}
locs_df$site_row <- seq_len(nrow(locs_df))
locs_df$selected <- as.integer(colSums(selection))
locs_df$selection_order <- NA_integer_
for (i in seq_len(iters)) locs_df$selection_order[which(selection[i, ] == 1)] <- i
locs_df$status <- ifelse(locs_df$vini == 1, "Current",
                         ifelse(locs_df$selected == 1, "Selected", "Demand"))

# Export demand points in selection order, with coordinates and input-row IDs.
selected_df <- locs_df[locs_df$selected == 1, ]
selected_df <- selected_df[order(selected_df$selection_order), ]
point_sel_path <- file.path(outputFolder, "point_Sel.csv")
write.csv(selected_df, point_sel_path, row.names = FALSE)
biab_output("point_sel", point_sel_path)

# Keep the original SURDES diagnostic calculation, now with explicit iterations.
uncov <- rowSums(result$pmmatrix)
uncov_df <- data.frame(iteration = seq_along(uncov), uncovered_variability = uncov)
uncov_path <- file.path(outputFolder, "uncov.csv")
write.csv(uncov_df, uncov_path, row.names = FALSE)
biab_output("uncov", uncov_path)

sites <- terra::vect(locs_df, geom = c("lon", "lat"), crs = "EPSG:4326")
sites_path <- file.path(outputFolder, "sampling_sites.gpkg")
terra::writeVector(sites, sites_path, filetype = "GPKG", overwrite = TRUE)
biab_output("sites_gpkg", sites_path)

surdes_uncov <- ggplot(uncov_df, aes(x = iteration, y = uncovered_variability)) +
  geom_point() + theme_bw() + labs(title = "SURDES uncovered-variability diagnostic",
                                  x = "Iteration", y = "Sum of p-median scores")
surdes_uncov_path <- file.path(outputFolder, "surdes_uncov.png")
ggsave(filename = surdes_uncov_path, plot = surdes_uncov, width = 10, height = 5, dpi = 300, bg = "white")
biab_output("surdes_uncov", surdes_uncov_path)

map_shp <- terra::project(terra::vect(input$country_polygon), "EPSG:4326")
surdes_map <- ggplot() + geom_spatvector(data = map_shp) +
  geom_spatvector(data = sites, aes(color = status), alpha = 0.5) +
  scale_color_manual(values = c(Current = "#56B4E9", Demand = "red", Selected = "#D55E00")) +
  theme_bw() + labs(title = "Site selection using environmental and geodesic distances", color = "Site status")
surdes_map_path <- file.path(outputFolder, "surdes_map.png")
ggsave(filename = surdes_map_path, plot = surdes_map, width = 10, height = 5, dpi = 300, bg = "white")
biab_output("surdes_map", surdes_map_path)
