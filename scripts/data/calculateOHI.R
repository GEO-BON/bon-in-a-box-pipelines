library(tidyverse)
library(sf)
library(rredlist)
library(here)

# Set your IUCN API key
IUCN_API_KEY <- Sys.getenv("IUCN_TOKEN")

# IUCN threat weights
threat_weights <- tribble(
  ~category, ~code, ~weight,
  "Extinct", "EX", 0.0,
  "Critically Endangered", "CR", 0.2,
  "Endangered", "EN", 0.4,
  "Vulnerable", "VU", 0.6,
  "Near Threatened", "NT", 0.8,
  "Least Concern", "LC", 1.0
)

# Floor value for catastrophic biodiversity loss
CATASTROPHIC_FLOOR <- 0.25

# Load inputs
input <- biab_inputs()
eez_boundaries <- st_read(input$EEZ)
bbox <- input$country_region_bbox$bbox
sp_status <- read.csv(input$sp_status)

print(head(sp_status))

biab_error_stop("")


#' Create grid covering the selected EEZ region(s)
#' @param eez_boundaries SF object with EEZ boundaries (already filtered by user)
#' @param resolution Grid resolution in degrees (default 0.5)
#' @param buffer_degrees Buffer around EEZs in degrees (default 2)
#' @return Grid covering the region
create_regional_grid <- function(eez_boundaries,
                                 resolution = 0.5,
                                 buffer_degrees = 2) {
  cat("Creating grid for selected region(s)...\n")

  # Get bounding box of all selected EEZs
  region_bbox <- st_bbox(eez_boundaries)

  # Add buffer
  bbox_buffered <- c(
    xmin = max(region_bbox["xmin"] - buffer_degrees, -180),
    xmax = min(region_bbox["xmax"] + buffer_degrees, 180),
    ymin = max(region_bbox["ymin"] - buffer_degrees, -90),
    ymax = min(region_bbox["ymax"] + buffer_degrees, 90)
  )
  # Create grid cells
  lon_seq <- seq(bbox_buffered["xmin"],
    bbox_buffered["xmax"],
    by = resolution
  )
  lat_seq <- seq(bbox_buffered["ymin"],
    bbox_buffered["ymax"],
    by = resolution
  )

  # Ensure we don't exceed bounds
  lon_seq <- lon_seq[lon_seq < bbox_buffered["xmax"]]
  lat_seq <- lat_seq[lat_seq < bbox_buffered["ymax"]]

  grid_cells <- expand.grid(
    lon = lon_seq,
    lat = lat_seq
  ) %>%
    mutate(
      cell_id = row_number(),
      geometry = pmap(
        list(lon, lat),
        function(x, y) {
          st_polygon(list(cbind(
            c(x, x + resolution, x + resolution, x, x),
            c(y, y, y + resolution, y + resolution, y)
          )))
        }
      )
    )

  # Convert to sf object
  grid <- st_sf(
    cell_id = grid_cells$cell_id,
    geometry = st_sfc(grid_cells$geometry, crs = 4326)
  )

  # Calculate areas
  grid <- grid %>%
    mutate(area_km2 = as.numeric(st_area(.) / 1e6))

  return(grid)
}

#' Filter species ranges to region of interest
#' @param range_maps SF object with all species ranges
#' @param eez_boundaries Filtered EEZ boundaries
#' @param buffer_degrees Buffer in degrees
#' @return Filtered species ranges
filter_ranges_to_region <- function(range_maps,
                                    eez_boundaries,
                                    buffer_degrees = 2) {
  cat("Filtering species ranges to selected region...\n")

  # Get bounding box with buffer
  region_bbox <- st_bbox(eez_boundaries)
  bbox_buffered <- st_bbox(
    c(
      xmin = region_bbox["xmin"] - buffer_degrees,
      xmax = region_bbox["xmax"] + buffer_degrees,
      ymin = region_bbox["ymin"] - buffer_degrees,
      ymax = region_bbox["ymax"] + buffer_degrees
    ),
    crs = st_crs(eez_boundaries)
  ) %>% st_as_sfc()

  # Filter ranges that intersect with buffered bbox
  filtered_ranges <- range_maps %>%
    st_filter(bbox_buffered)

  n_species <- length(unique(filtered_ranges$species_id))
  cat(sprintf("  Found %d species in region\n\n", n_species))

  return(filtered_ranges)
}

# Calculate area-weighted species risk status
calculate_species_status <- function(species_by_cell,
                                     species_threat,
                                     cell_countries) {
  # Join threat weights to species data
  species_data <- species_by_cell %>%
    left_join(species_threat, by = "species_id") %>%
    left_join(threat_weights, by = c("category" = "category")) %>%
    filter(!is.na(weight))

  # Join cell countries
  species_data <- species_data %>%
    left_join(cell_countries, by = "cell_id") %>%
    filter(!is.na(country_id))

  # Calculate per-cell statistics
  cell_stats <- species_data %>%
    group_by(country_id, country_name, cell_id, area_km2) %>%
    summarize(
      sum_weights = sum(weight, na.rm = TRUE),
      n_species = n(),
      .groups = "drop"
    )

  # Calculate country-level scores
  country_scores <- cell_stats %>%
    group_by(country_id, country_name) %>%
    summarize(
      numerator = sum(sum_weights * area_km2),
      denominator = sum(area_km2 * n_species),
      total_area = sum(area_km2),
      total_species = sum(n_species),
      n_cells = n(),
      .groups = "drop"
    ) %>%
    mutate(R_spp = numerator / denominator)

  return(country_scores)
}

# Convert R_spp to final status score
calculate_status_score <- function(R_spp) {
  # Equation 6.5: x_spp = max((R_spp - 0.25) / 0.75, 0)
  status <- pmax((R_spp - CATASTROPHIC_FLOOR) / (1 - CATASTROPHIC_FLOOR), 0)
  return(status)
}

######## Run OHI Species Condition Model ########

# Validate inputs
if (nrow(eez_boundaries) == 0) {
  stop("No EEZ boundaries found.")
}

# Step 1: Create regional grid
cat("Step 1: Creating grid for selected EEZ(s)...\n")
grid <- create_regional_grid(eez_boundaries)

# Step 2: Load and filter species ranges
cat("Step 2: Loading species range maps...\n")
all_ranges <- st_read(input$range_maps, quiet = TRUE)

biabt_error_stop("stop")

# Standardize species ID column
if ("binomial" %in% names(all_ranges)) {
  all_ranges <- all_ranges %>% rename(species_id = binomial)
} else if ("BINOMIAL" %in% names(all_ranges)) {
  all_ranges <- all_ranges %>% rename(species_id = BINOMIAL)
} else if ("sci_name" %in% names(all_ranges)) {
  all_ranges <- all_ranges %>% rename(species_id = sci_name)
}

range_maps <- filter_ranges_to_region(
  all_ranges,
  eez_boundaries,
  buffer_degrees = buffer_degrees
)

# Step 3: Get species threat data if not provided
# need species threat input? is this the categorization?

# Step 4: Intersect ranges with grid
cat("Step 4: Intersecting species ranges with grid...\n")

species_by_cell <- st_intersection(range_maps, grid) %>%
  st_drop_geometry() %>%
  select(species_id, cell_id, area_km2) %>%
  distinct()

# Step 5: Assign cells to countries/EEZs
cat("Step 5: Assigning grid cells to countries...\n")

grid_centroids <- st_centroid(grid)
cell_countries <- st_join(grid_centroids, eez_boundaries, join = st_within) %>%
  st_drop_geometry()

# Extract country ID and name (handle different column names)
id_col <- names(cell_countries)[names(cell_countries) %in%
  c("MRGID", "EEZ_ID", "id", "ID")][1]
name_col <- names(cell_countries)[names(cell_countries) %in%
  c(
    "GEONAME", "SOVEREIGN1", "TERRITORY1",
    "name", "NAME", "Country"
  )][1]

if (!is.na(id_col) && !is.na(name_col)) {
  cell_countries <- cell_countries %>%
    select(cell_id, country_id = !!sym(id_col), country_name = !!sym(name_col)) %>%
    filter(!is.na(country_id)) %>%
    distinct()
} else {
  # Fallback: create simple assignment
  cell_countries <- cell_countries %>%
    mutate(
      country_id = 1,
      country_name = "Study Region"
    ) %>%
    select(cell_id, country_id, country_name) %>%
    distinct()
}

# Step 6: Calculate status scores
cat("Step 6: Calculating species status scores...\n")

country_scores <- calculate_species_status(
  species_by_cell,
  species_threat,
  cell_countries
)

final_scores <- country_scores %>%
  mutate(
    status_score = calculate_status_score(R_spp),
    year = lubridate::year(Sys.Date())
  ) %>%
  arrange(desc(status_score))

# Step 7: Save results
cat("Step 7: Saving results...\n")
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

write_csv(final_scores, file.path(output_dir, "species_status_scores.csv"))
write_csv(species_by_cell, file.path(output_dir, "species_by_cell.csv"))
write_csv(cell_countries, file.path(output_dir, "cell_countries.csv"))
write_csv(species_threat, file.path(output_dir, "species_threat_data.csv"))

# Summary statistics
summary <- final_scores %>%
  summarize(
    n_countries = n(),
    mean_score = mean(status_score, na.rm = TRUE),
    median_score = median(status_score, na.rm = TRUE),
    min_score = min(status_score, na.rm = TRUE),
    max_score = max(status_score, na.rm = TRUE),
    countries_below_threshold = sum(status_score < CATASTROPHIC_FLOOR)
  )

write_csv(summary, file.path(output_dir, "summary_statistics.csv"))

################################################################################
# 5. VISUALIZATION FUNCTIONS
################################################################################

#' Plot species status scores by country
plot_country_status <- function(status_data, save_path = NULL) {
  p <- ggplot(status_data, aes(
    x = reorder(country_name, status_score),
    y = status_score
  )) +
    geom_col(fill = "steelblue", alpha = 0.8) +
    geom_hline(
      yintercept = CATASTROPHIC_FLOOR,
      linetype = "dashed",
      color = "red",
      linewidth = 1
    ) +
    coord_flip() +
    labs(
      title = "OHI Species Condition Status by Country",
      subtitle = paste("Red line indicates catastrophic threshold (",
        CATASTROPHIC_FLOOR, ")",
        sep = ""
      ),
      x = "Country/Region",
      y = "Status Score (0-1)",
      caption = "Based on IUCN Red List species assessments"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(size = 14, face = "bold"),
      axis.text = element_text(size = 10)
    )

  if (!is.null(save_path)) {
    ggsave(save_path, p, width = 10, height = 6, dpi = 300)
  }

  return(p)
}

#' Create a map of the analysis region with scores
plot_regional_map <- function(results, eez_boundaries, save_path = NULL) {
  # Join scores to EEZ boundaries
  eez_with_scores <- eez_boundaries %>%
    left_join(
      results$scores %>% select(country_id, status_score),
      by = c("MRGID" = "country_id") # Adjust column name as needed
    )

  p <- ggplot() +
    geom_sf(
      data = eez_with_scores, aes(fill = status_score),
      color = "white", size = 0.2
    ) +
    scale_fill_viridis_c(
      name = "Status\nScore",
      limits = c(0, 1),
      option = "plasma"
    ) +
    labs(
      title = "OHI Species Condition Status",
      subtitle = "By Country EEZ"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(size = 14, face = "bold"),
      legend.position = "right"
    )

  if (!is.null(save_path)) {
    ggsave(save_path, p, width = 12, height = 8, dpi = 300)
  }

  return(p)
}

################################################################################
# 6. EXAMPLE USAGE
################################################################################

# Example workflow:
#
# library(sf)
# source("ohi_species_condition_country.R")
#
# # Step 1: Load all EEZs
# all_eez <- st_read("data/eez_v11/eez_v11.shp")
#
# # Step 2: Filter to your region of interest (YOU do this)
# # Option A: By bounding box
# my_bbox <- st_bbox(c(xmin = -85, xmax = -60, ymin = 10, ymax = 25), crs = 4326)
# my_eezs <- st_crop(all_eez, my_bbox)
#
# # Option B: By country codes
# my_eezs <- all_eez %>% filter(ISO_SOV1 %in% c("USA", "CAN", "MEX"))
#
# # Option C: By country names
# my_eezs <- all_eez %>% filter(SOVEREIGN1 %in% c("United States", "Canada"))
#
# # Step 3: Run the model with your pre-filtered EEZs
# results <- run_species_condition_model(
#   range_maps_path = "data/IUCN_ranges/marine_species.shp",
#   eez_boundaries = my_eezs,
#   grid_resolution = 0.5,
#   output_dir = "output/my_region"
# )
#
# # Step 4: Visualize results
# plot_country_status(results$scores,
#                     save_path = "output/my_region/country_scores.png")
