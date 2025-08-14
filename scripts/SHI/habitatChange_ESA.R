library(tidyverse)

input <- biab_inputs()

layers <- terra::rast(c(input$layers))
print("Rasters:")
print(layers)
values <- terra::values(layers[[1]])
habitats <- input$habitats
aoh_paths <- input$aoh
start_year <- input$start_year
end_year <- input$end_year

species_names <- basename(dirname(aoh_paths))
n_species <- length(aoh_paths)

# Define output paths
raster_path <- c()
change_map_path <- c()
df_all_area_scores <- tibble()

# Loop through each layer
for (s in 1:n_species) {
  print("========== Filtering by habitat type... ==========")

  species_aoh <- terra::rast(aoh_paths[s])
  species_name <- species_names[s]

  processed_layers <- list()
  layers_without_aoh_mask <- list()

  for (i in 1:2) {
    layer <- layers[[i]]

    if (length(habitats) > 0) {
      # Mask unwanted land cover types
      layer[!(layer[] %in% habitats)] <- NA
    }

    # Resample land cover raster to match area of habitat
    layer <- terra::resample(layer, species_aoh, method = "near")

    # Keep layers without aoh mask for analysis later
    layers_without_aoh_mask[[i]] <- layer

    # Crop to area of habitat of species
    layer <- terra::crop(layer, species_aoh)

    # Mask using AOH
    layer <- terra::mask(layer, species_aoh)

    # Store processed layer
    processed_layers[[i]] <- layer
  }

  # Combine processed layers into one SpatRaster
  processed_raster <- terra::rast(processed_layers)
  no_mask_raster <- terra::rast(layers_without_aoh_mask)

  # Create species-specific output path
  raster_path[s] <- file.path(outputFolder, paste0(species_name, "_raster.tif"))
  terra::writeRaster(processed_raster, filename = raster_path[s], overwrite = TRUE)

  print(sprintf("========== Measuring habitat change for %s... ==========", species_name))

  # Extract the two processed layers
  r1 <- processed_layers[[1]]
  r2 <- processed_layers[[2]]
  # Convert habitat presence to binary (1 = habitat, NA = no habitat)
  r1_bin <- r1
  r1_bin[!is.na(r1_bin)] <- 4

  r2_bin <- r2
  r2_bin[!is.na(r2_bin)] <- 4

  change_map <- r1_bin
  change_map[] <- NA
  change_map[r1_bin == 4 & (is.na(r2_bin) | r2_bin != 4)] <- 1 # Habitat loss
  change_map[(is.na(r1_bin) | r1_bin != 4) & r2_bin == 4] <- 2 # Habitat gain
  change_map[(r1_bin == 4 & r2_bin == 4)] <- 3 # No change

  # Write change map raster to file
  change_map_path[s] <- file.path(outputFolder, paste0(species_name, "_habitat_change_map.tif"))

  terra::writeRaster(
    change_map,
    filename = change_map_path[s],
    overwrite = TRUE
  )
  print(sprintf("========== Calculating area score for %s... ==========", species_name))

  r1[!is.na(r1)] <- 1
  r2[!is.na(r2)] <- 1

  full_raster <- c(r1, r2)

  # Calculate pixel area
  if (terra::crs(full_raster, proj = TRUE) == "EPSG:4326") {
    r_areas <- terra::cellSize(full_raster[[1]], unit = "ha")
  } else {
    spatial_res <- terra::res(full_raster)[1]
    area_m2 <- (spatial_res^2) / 1000
    r_areas <- full_raster[[1]]
    r_areas[] <- area_m2
  }

  # Multiply habitat presence by pixel area
  s_habitat_area <- full_raster * r_areas

  # Sum habitat area per layer
  habitat_area <- terra::global(s_habitat_area, sum, na.rm = TRUE)

  # Create area score table
  df_area_score <- tibble(
    sci_name = species_name,
    Year = c(start_year, end_year),
    Area = units::set_units(habitat_area$sum, "ha")
  ) |>
    dplyr::mutate(ref_area = first(Area)) |>
    dplyr::group_by(Year) |>
    dplyr::mutate(
      diff = ref_area - Area,
      percentage = as.numeric(Area * 100 / ref_area),
      score = "AS"
    )
  # Save
  df_all_area_scores <- bind_rows(df_all_area_scores, df_area_score)

  print(sprintf("========== Calculating connectivity score for %s... ==========", species_name))

  r1_nomask <- processed_layers_nomask[[1]]
  r2_nomask <- processed_layers_nomask[[2]]
  r1_nomask[!is.na(r1_nomask)] <- 1
  r2_nomask[!is.na(r2_nomask)] <- 1
  r1_nomask[is.na(r1_nomask)] <- 0
  r2_nomask[is.na(r2_nomask)] <- 0

  print(table(terra::values(r1_nomask)))

}
df_area_score_path <- file.path(outputFolder, paste0("df_area_score.tsv"))
write_tsv(df_all_area_scores, df_area_score_path)

biab_output("shs_table", df_area_score_path)
biab_output("raster", raster_path)
biab_output("habitat_change_map", change_map_path)