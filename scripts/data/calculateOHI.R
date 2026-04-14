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
print(sprintf("  Loaded EEZ with %d region(s)\n", nrow(eez_boundaries)))

# Load species status data
sp_status <- read.csv(input$sp_status)
print(sprintf("  Loaded status for %d species\n", nrow(sp_status)))

# Prepare species threat data (rename columns to match model expectations)
species_threat <- sp_status %>%
  select(
    species_id = scientific_name,
    category = red_list_category_code
  ) %>%
  filter(!is.na(category)) %>%
  filter(!category %in% c("DD", "NE")) %>%  # Remove Data Deficient, Not Evaluated
  distinct()

print(sprintf("  Prepared threat data for %d species\n", nrow(species_threat)))

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

  # Add buffer - clamp to valid bounds (avoid exact poles)
  bbox_buffered <- c(
    xmin = max(region_bbox["xmin"] - buffer_degrees, -180),
    xmax = min(region_bbox["xmax"] + buffer_degrees, 180),
    ymin = max(region_bbox["ymin"] - buffer_degrees, -89.9),
    ymax = min(region_bbox["ymax"] + buffer_degrees, 89.9)
  )

  print(sprintf("  Grid bbox: [%.2f, %.2f, %.2f, %.2f]\n",
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

  print(sprintf("  Created %d grid cells\n", nrow(grid)))

  return(grid)
}

#' Load all range maps from file path vector (handling empty/NA files)
#' Also filters to region of interest during loading to avoid geometry issues
load_range_maps <- function(range_files, species_list, eez_boundaries, buffer_degrees = 2) {

  cat("\nStep 2: Loading species range maps...\n")

  print(sprintf("  Found %d range map files\n", length(range_files)))

  if (length(range_files) == 0) {
    stop("No range map files provided!")
  }
  
  # Make EEZ boundaries valid first
  eez_valid <- st_make_valid(eez_boundaries)
  
  # Create bounding box for filtering
  region_bbox <- st_bbox(eez_valid)
  
  # Check for NA values in bbox
  if (any(is.na(region_bbox))) {
    print("  WARNING: EEZ bounding box contains NA values. Attempting to fix...")
    # Try to get bbox from union of all geometries
    eez_union <- st_union(eez_valid)
    region_bbox <- st_bbox(eez_union)
  }
  
  # If still NA, stop with helpful error
  if (any(is.na(region_bbox))) {
    stop("Could not compute valid bounding box from EEZ boundaries. Check that EEZ file has valid geometries.")
  }
  
  print(sprintf("  Region bbox: [%.2f, %.2f, %.2f, %.2f]\n",
                region_bbox["xmin"], region_bbox["xmax"],
                region_bbox["ymin"], region_bbox["ymax"]))
  
  # Create buffered bbox manually (avoiding st_bbox which can fail)
  # Clamp to valid geographic bounds (avoid exact poles which cause issues)
  xmin_buf <- max(region_bbox["xmin"] - buffer_degrees, -180)
  xmax_buf <- min(region_bbox["xmax"] + buffer_degrees, 180)
  ymin_buf <- max(region_bbox["ymin"] - buffer_degrees, -89.9)  # Avoid exact pole
  ymax_buf <- min(region_bbox["ymax"] + buffer_degrees, 89.9)   # Avoid exact pole
  
  # Create polygon from coordinates directly
  bbox_coords <- matrix(c(
    xmin_buf, ymin_buf,
    xmax_buf, ymin_buf,
    xmax_buf, ymax_buf,
    xmin_buf, ymax_buf,
    xmin_buf, ymin_buf
  ), ncol = 2, byrow = TRUE)
  
  bbox_buffered <- st_sfc(st_polygon(list(bbox_coords)), crs = st_crs(eez_valid))

  # Load each range map and combine
  all_ranges <- NULL
  successful <- 0
  skipped <- 0

  for (i in seq_along(range_files)) {
    file <- range_files[i]

    if (i %% 10 == 0) {
      print(sprintf("  Processing file %d of %d...\n", i, length(range_files)))
    }

    tryCatch({
      # Try to read the file
      range_map <- st_read(file, quiet = TRUE)

      # Check if it's empty or has no geometries
      if (nrow(range_map) == 0 || all(st_is_empty(range_map))) {
        skipped <- skipped + 1
        next
      }
      
      # Make geometries valid
      range_map <- st_make_valid(range_map)
      
      # Ensure CRS matches
      if (is.na(st_crs(range_map))) {
        st_crs(range_map) <- 4326
      } else if (st_crs(range_map) != st_crs(eez_valid)) {
        range_map <- st_transform(range_map, st_crs(eez_valid))
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
        print(sprintf("    No standard column found in: %s\n", basename(file)))
        print(sprintf("    Available columns: %s\n", paste(names(range_map), collapse=", ")))
        
        # Try to extract from directory name (parent folder)
        species_name <- basename(dirname(file))
        print(sprintf("    Parent directory: '%s'\n", species_name))

        # If that doesn't work, try extracting from filename
        if (species_name == "" || species_name == "." ||
            grepl("^[0-9a-f]{8,}$", species_name, ignore.case = TRUE)) {  # Skip hash directories (8+ hex chars)
          # Try to extract from filename - remove common suffixes
          filename <- basename(file)
          # Remove file extension first
          species_name <- tools::file_path_sans_ext(filename)
          # Remove common patterns like _range, _map, _distribution, etc.
          species_name <- gsub("_(range|map|distribution|habitat)$", "", species_name, ignore.case = TRUE)
          species_name <- gsub("^range_|^map_", "", species_name, ignore.case = TRUE)
          print(sprintf("    Extracted from filename: '%s'\n", species_name))
        }

        # Final cleanup: replace underscores with spaces for binomial names
        if (species_name != "" && species_name != "." && 
            !grepl("^[0-9a-f]{8,}$", species_name, ignore.case = TRUE)) {  # Not a hash
          species_name <- gsub("_", " ", species_name)
          range_map <- range_map %>%
            mutate(species_id = species_name)
          print(sprintf("    Final species name: '%s'\n", species_name))
        } else {
          print(sprintf("    WARNING: Could not extract valid species ID from %s\n", file))
          skipped <- skipped + 1
          next
        }
      }

      # Keep only species_id and geometry, filter empty geometries
      geom_col <- attr(range_map, "sf_column")
      range_map_clean <- range_map[, c("species_id", geom_col)]
      range_map_clean <- range_map_clean[!st_is_empty(range_map_clean), ]
      
      if (nrow(range_map_clean) == 0) {
        skipped <- skipped + 1
        next
      }
      
      # Filter to region of interest NOW (before combining)
      intersects_bbox <- st_intersects(range_map_clean, bbox_buffered, sparse = FALSE)
      range_map_filtered <- range_map_clean[intersects_bbox[, 1], ]
      
      if (nrow(range_map_filtered) == 0) {
        # No intersection with region - skip
        skipped <- skipped + 1
        next
      }
      
      # Rename geometry column to 'geom' for consistency
      if (geom_col != "geom") {
        names(range_map_filtered)[names(range_map_filtered) == geom_col] <- "geom"
        st_geometry(range_map_filtered) <- "geom"
      }

      # Combine with existing data
      if (is.null(all_ranges)) {
        all_ranges <- range_map_filtered
      } else {
        all_ranges <- rbind(all_ranges, range_map_filtered)
      }
      successful <- successful + 1

    }, error = function(e) {
      # Log the error and skip file
      print(sprintf("    ERROR reading file: %s\n", file))
      print(sprintf("    Error message: %s\n", conditionMessage(e)))
      skipped <<- skipped + 1
    })
  }

  print(sprintf("  Successfully loaded: %d files\n", successful))
  print(sprintf("  Skipped (empty/invalid/outside region): %d files\n", skipped))

  # Check if any ranges were loaded
  if (is.null(all_ranges)) {
    stop(sprintf(
      "No valid range maps were loaded!\n  Total files attempted: %d\n  Successfully loaded: %d\n  Skipped: %d\n  Check the error messages above for details.",
      length(range_files), successful, skipped
    ))
  }

  # Final cleanup - make valid and remove any remaining issues  
  all_ranges <- st_make_valid(all_ranges)
  all_ranges <- all_ranges[st_is_valid(all_ranges), ]
  all_ranges <- distinct(all_ranges)

  n_species <- length(unique(all_ranges$species_id))
  print(sprintf("  Total: %d unique species with valid ranges in region\n", n_species))

  return(all_ranges)
}

#' Filter species ranges to region of interest
filter_ranges_to_region <- function(range_maps,
                                    eez_boundaries,
                                    buffer_degrees = 2) {

  cat("\n  Filtering species ranges to selected region...\n")

  # Make EEZ valid first
  eez_valid <- st_make_valid(eez_boundaries)
  
  # Get bounding box with buffer
  region_bbox <- st_bbox(eez_valid)
  
  # Create buffered bbox manually - clamp to valid bounds
  xmin_buf <- max(region_bbox["xmin"] - buffer_degrees, -180)
  xmax_buf <- min(region_bbox["xmax"] + buffer_degrees, 180)
  ymin_buf <- max(region_bbox["ymin"] - buffer_degrees, -89.9)  # Avoid exact pole
  ymax_buf <- min(region_bbox["ymax"] + buffer_degrees, 89.9)   # Avoid exact pole
  
  bbox_coords <- matrix(c(
    xmin_buf, ymin_buf,
    xmax_buf, ymin_buf,
    xmax_buf, ymax_buf,
    xmin_buf, ymax_buf,
    xmin_buf, ymin_buf
  ), ncol = 2, byrow = TRUE)
  
  bbox_buffered <- st_sfc(st_polygon(list(bbox_coords)), crs = st_crs(eez_valid))

  # Process each row individually to avoid NA geometry issues
  filtered_list <- list()
  n_total <- nrow(range_maps)
  
  for (i in seq_len(n_total)) {
    if (i %% 100 == 0) {
      print(sprintf("  Filtering range %d of %d...\n", i, n_total))
    }
    
    tryCatch({
      row <- range_maps[i, ]
      
      # Skip if geometry is NA or empty
      if (is.na(st_geometry(row)) || st_is_empty(row)) {
        next
      }
      
      # Check if this row intersects with bbox
      if (st_intersects(row, bbox_buffered, sparse = FALSE)[1, 1]) {
        filtered_list[[length(filtered_list) + 1]] <- row
      }
    }, error = function(e) {
      # Skip problematic rows
    })
  }
  
  # Combine filtered results
  if (length(filtered_list) > 0) {
    filtered_ranges <- do.call(rbind, filtered_list)
  } else {
    filtered_ranges <- range_maps[0, ]  # Empty sf with same structure
  }

  n_species <- length(unique(filtered_ranges$species_id))
  print(sprintf("  Found %d species in region\n", n_species))

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

# Step 2: Load all range maps from file paths (also filters to region)
all_ranges <- load_range_maps(
  range_files = input$range_maps,  # Vector of file paths
  species_list = species_threat$species_id,
  eez_boundaries = eez_boundaries,
  buffer_degrees = 2
)

# Filter to species that are in both threat data and range maps
common_species <- intersect(
  unique(all_ranges$species_id),
  unique(species_threat$species_id)
)

print(sprintf("\n  Species overlap: %d species in both threat data and range maps\n",
            length(common_species)))

# Filter range maps to common species
range_maps <- all_ranges %>%
  filter(species_id %in% common_species)

# Filter threat data to common species
species_threat <- species_threat %>%
  filter(species_id %in% common_species)

# Step 3: Intersect ranges with grid
cat("\nStep 3: Intersecting species ranges with grid...\n")
cat("  This may take a few minutes...\n")

species_by_cell <- st_intersection(range_maps, grid) %>%
  st_drop_geometry() %>%
  select(species_id, cell_id, area_km2) %>%
  distinct()

print(sprintf("  Found %d species-cell combinations\n", nrow(species_by_cell)))

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

print(sprintf("  Assigned %d cells to study region\n", nrow(cell_countries)))

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

print(sprintf("  Calculated scores for %d region\n", nrow(final_scores)))

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
print(sprintf("  Status Score: %.3f\n", final_scores$status_score))
print(sprintf("  R_spp: %.3f\n", final_scores$R_spp))
print(sprintf("  Total species analyzed: %d\n", final_scores$total_species))
print(sprintf("  Grid cells: %d\n", final_scores$n_cells))
print(sprintf("  Below catastrophic threshold (0.25): %s\n",
            ifelse(final_scores$status_score < CATASTROPHIC_FLOOR, "YES", "NO")))
print(sprintf("\nResults saved to: %s\n\n", output_dir))
