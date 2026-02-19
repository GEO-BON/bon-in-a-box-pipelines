################################################################################
# OHI Species Condition Model - Adapted for Your Data Structure
################################################################################

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

################################################################################
# LOAD INPUTS
################################################################################

cat("Loading inputs...\n")
input <- biab_inputs()

# Load EEZ boundaries
eez_boundaries <- st_read(input$EEZ, quiet = TRUE)
cat(sprintf("  Loaded EEZ with %d region(s)\n", nrow(eez_boundaries)))

# Load species status data
sp_status <- read.csv(input$sp_status)
cat(sprintf("  Loaded status for %d species\n", nrow(sp_status)))

# Prepare species threat data (rename columns to match model expectations)
species_threat <- sp_status %>%
  select(
    species_id = scientific_name,
    category = red_list_category_code
  ) %>%
  filter(!is.na(category)) %>%
  filter(!category %in% c("DD", "NE")) %>%  # Remove Data Deficient, Not Evaluated
  distinct()

cat(sprintf("  Prepared threat data for %d species\n", nrow(species_threat)))

# Get bbox
bbox <- input$country_region_bbox$bbox

# Set output directory
output_dir <- "output/species_condition"

################################################################################
# HELPER FUNCTIONS
################################################################################

#' Create grid covering the selected EEZ region(s)
create_regional_grid <- function(eez_boundaries,
                                 resolution = 0.5,
                                 buffer_degrees = 2) {

  cat("\nStep 1: Creating grid for selected region(s)...\n")

  # Get bounding box of all selected EEZs
  region_bbox <- st_bbox(eez_boundaries)

  # Add buffer
  bbox_buffered <- c(
    xmin = max(region_bbox["xmin"] - buffer_degrees, -180),
    xmax = min(region_bbox["xmax"] + buffer_degrees, 180),
    ymin = max(region_bbox["ymin"] - buffer_degrees, -90),
    ymax = min(region_bbox["ymax"] + buffer_degrees, 90)
  )

  cat(sprintf("  Grid bbox: [%.2f, %.2f, %.2f, %.2f]\n",
              bbox_buffered["xmin"], bbox_buffered["xmax"],
              bbox_buffered["ymin"], bbox_buffered["ymax"]))

  # Create grid cells
  lon_seq <- seq(bbox_buffered["xmin"],
                 bbox_buffered["xmax"],
                 by = resolution)
  lat_seq <- seq(bbox_buffered["ymin"],
                 bbox_buffered["ymax"],
                 by = resolution)

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

  cat(sprintf("  Created %d grid cells\n", nrow(grid)))

  return(grid)
}

#' Load all range maps from file path vector (handling empty/NA files)
load_range_maps <- function(range_files, species_list) {

  cat("\nStep 2: Loading species range maps...\n")

  cat(sprintf("  Found %d range map files\n", length(range_files)))

  if (length(range_files) == 0) {
    stop("No range map files provided!")
  }

  # Load each range map and combine
  all_ranges_list <- list()
  successful <- 0
  skipped <- 0

  for (i in seq_along(range_files)) {
    file <- range_files[i]

    if (i %% 10 == 0) {
      cat(sprintf("  Processing file %d of %d...\n", i, length(range_files)))
    }

    tryCatch({
      # Try to read the file
      range_map <- st_read(file, quiet = TRUE)

      # Check if it's empty or has no geometries
      if (nrow(range_map) == 0 || all(st_is_empty(range_map))) {
        skipped <- skipped + 1
        next
      }

      # Standardize species ID column (check multiple possible names)
      if ("binomial" %in% names(range_map)) {
        range_map <- range_map %>% rename(species_id = binomial)
      } else if ("BINOMIAL" %in% names(range_map)) {
        range_map <- range_map %>% rename(species_id = BINOMIAL)
      } else if ("sci_name" %in% names(range_map)) {
        range_map <- range_map %>% rename(species_id = sci_name)
      } else if ("scientific_name" %in% names(range_map)) {
        range_map <- range_map %>% rename(species_id = scientific_name)
      } else if ("SCINAME" %in% names(range_map)) {
        range_map <- range_map %>% rename(species_id = SCINAME)
      } else {
        # If no recognized column, extract from filename/path
        # Your format: ".../ Rhincodon typus/Rhincodon typus_range.gpkg"

        # Try to extract from directory name (parent folder)
        species_name <- basename(dirname(file))

        # If that doesn't work, try extracting from filename
        if (species_name == "" || species_name == "." ||
            grepl("^[0-9a-f]{32}$", species_name)) {  # Skip hash directories
          # Try to extract from filename: "Rhincodon typus_range.gpkg"
          filename <- basename(file)
          species_name <- gsub("_range\\.gpkg$", "", filename)
        }

        if (species_name != "" && species_name != ".") {
          range_map <- range_map %>%
            mutate(species_id = species_name)
          cat(sprintf("    Extracted species name '%s' from file path\n", species_name))
        } else {
          warning(sprintf("Could not extract species ID from %s", file))
          skipped <- skipped + 1
          next
        }
      }

      # Keep only relevant columns and valid geometries
      range_map_clean <- range_map %>%
        select(species_id, geometry) %>%
        filter(!st_is_empty(geometry))

      if (nrow(range_map_clean) > 0) {
        all_ranges_list[[length(all_ranges_list) + 1]] <- range_map_clean
        successful <- successful + 1
      } else {
        skipped <- skipped + 1
      }

    }, error = function(e) {
      # Skip files that can't be read or are corrupt
      skipped <<- skipped + 1
    })
  }

  cat(sprintf("  Successfully loaded: %d files\n", successful))
  cat(sprintf("  Skipped (empty/invalid): %d files\n", skipped))

  # Combine all valid ranges
  if (length(all_ranges_list) == 0) {
    stop("No valid range maps were loaded!")
  }

  all_ranges <- bind_rows(all_ranges_list)

  # Remove duplicates and ensure valid geometries
  all_ranges <- all_ranges %>%
    filter(st_is_valid(geometry)) %>%
    distinct()

  n_species <- length(unique(all_ranges$species_id))
  cat(sprintf("  Total: %d unique species with valid ranges\n", n_species))

  return(all_ranges)
}

#' Filter species ranges to region of interest
filter_ranges_to_region <- function(range_maps,
                                    eez_boundaries,
                                    buffer_degrees = 2) {

  cat("\n  Filtering species ranges to selected region...\n")

  # Get bounding box with buffer
  region_bbox <- st_bbox(eez_boundaries)
  bbox_buffered <- st_bbox(
    c(xmin = region_bbox["xmin"] - buffer_degrees,
      xmax = region_bbox["xmax"] + buffer_degrees,
      ymin = region_bbox["ymin"] - buffer_degrees,
      ymax = region_bbox["ymax"] + buffer_degrees),
    crs = st_crs(eez_boundaries)
  ) %>% st_as_sfc()

  # Filter ranges that intersect with buffered bbox
  filtered_ranges <- range_maps %>%
    st_filter(bbox_buffered)

  n_species <- length(unique(filtered_ranges$species_id))
  cat(sprintf("  Found %d species in region\n", n_species))

  return(filtered_ranges)
}

#' Calculate area-weighted species risk status
calculate_species_status <- function(species_by_cell,
                                     species_threat,
                                     cell_countries) {

  # Join threat weights to species data
  species_data <- species_by_cell %>%
    left_join(species_threat, by = "species_id") %>%
    left_join(threat_weights, by = c("category" = "code")) %>%  # Match on 'code' column
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

#' Convert R_spp to final status score
calculate_status_score <- function(R_spp) {
  status <- pmax((R_spp - CATASTROPHIC_FLOOR) / (1 - CATASTROPHIC_FLOOR), 0)
  return(status)
}

################################################################################
# RUN MODEL
################################################################################

cat("\n========================================\n")
cat("OHI Species Condition Model\n")
cat("========================================\n\n")

# Validate inputs
if (nrow(eez_boundaries) == 0) {
  stop("No EEZ boundaries found.")
}

if (nrow(species_threat) == 0) {
  stop("No species threat data found.")
}

# Step 1: Create regional grid
grid <- create_regional_grid(
  eez_boundaries,
  resolution = 0.5,
  buffer_degrees = 2
)

# Step 2: Load all range maps from file paths
all_ranges <- load_range_maps(
  range_files = input$range_maps,  # Vector of file paths
  species_list = species_threat$species_id
)

# Filter to species that are in both threat data and range maps
common_species <- intersect(
  unique(all_ranges$species_id),
  unique(species_threat$species_id)
)

cat(sprintf("\n  Species overlap: %d species in both threat data and range maps\n",
            length(common_species)))

# Filter range maps to common species
all_ranges <- all_ranges %>%
  filter(species_id %in% common_species)

# Filter threat data to common species
species_threat <- species_threat %>%
  filter(species_id %in% common_species)

# Filter ranges to region
range_maps <- filter_ranges_to_region(
  all_ranges,
  eez_boundaries,
  buffer_degrees = 2
)

# Step 3: Intersect ranges with grid
cat("\nStep 3: Intersecting species ranges with grid...\n")
cat("  This may take a few minutes...\n")

species_by_cell <- st_intersection(range_maps, grid) %>%
  st_drop_geometry() %>%
  select(species_id, cell_id, area_km2) %>%
  distinct()

cat(sprintf("  Found %d species-cell combinations\n", nrow(species_by_cell)))

# Step 4: Assign cells to countries/EEZs
cat("\nStep 4: Assigning grid cells to study region...\n")

grid_centroids <- st_centroid(grid)

# Simple assignment: all cells within any EEZ belong to the study region
cell_countries <- st_join(grid_centroids, eez_boundaries, join = st_within) %>%
  st_drop_geometry() %>%
  filter(!is.na(MRGID)) %>%  # Keep only cells that intersect with EEZs
  select(cell_id) %>%
  distinct() %>%
  mutate(
    country_id = 1,
    country_name = "Study Region"
  )

cat(sprintf("  Assigned %d cells to study region\n", nrow(cell_countries)))

# Step 5: Calculate status scores
cat("\nStep 5: Calculating species status scores...\n")

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

cat(sprintf("  Calculated scores for %d region\n", nrow(final_scores)))

# Step 6: Save results
cat("\nStep 6: Saving results...\n")
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

write_csv(final_scores, file.path(output_dir, "species_status_scores.csv"))
write_csv(species_by_cell, file.path(output_dir, "species_by_cell.csv"))
write_csv(cell_countries, file.path(output_dir, "cell_countries.csv"))
write_csv(species_threat, file.path(output_dir, "species_threat_data.csv"))

# Save grid for visualization
st_write(grid, file.path(output_dir, "analysis_grid.gpkg"),
         delete_dsn = TRUE, quiet = TRUE)

# Summary statistics
summary <- final_scores %>%
  summarize(
    region_name = country_name,
    status_score = status_score,
    R_spp = R_spp,
    total_species = total_species,
    n_cells = n_cells,
    below_threshold = ifelse(status_score < CATASTROPHIC_FLOOR, 1, 0)
  )

write_csv(summary, file.path(output_dir, "summary_statistics.csv"))

# Display results
cat("\n========================================\n")
cat("Analysis Complete!\n")
cat("========================================\n\n")

cat("Study Region Results:\n")
cat("---------------------\n")
print(final_scores %>%
        select(status_score, R_spp, total_species, n_cells) %>%
        as.data.frame())

cat("\n\nSummary Statistics:\n")
cat("-------------------\n")
cat(sprintf("  Status Score: %.3f\n", final_scores$status_score))
cat(sprintf("  R_spp: %.3f\n", final_scores$R_spp))
cat(sprintf("  Total species analyzed: %d\n", final_scores$total_species))
cat(sprintf("  Grid cells: %d\n", final_scores$n_cells))
cat(sprintf("  Below catastrophic threshold (0.25): %s\n",
            ifelse(final_scores$status_score < CATASTROPHIC_FLOOR, "YES", "NO")))
cat(sprintf("\nResults saved to: %s\n\n", output_dir))
