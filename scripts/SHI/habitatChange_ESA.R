library(tidyverse)
library(terra)

## Load inputs ##
input <- biab_inputs()

layers <- rast(c(input$layers))
habitats <- input$habitats
aoh_paths <- input$aoh
start_year <- input$start_year
end_year <- input$end_year

# Get number of species and species names
species_names <- basename(dirname(aoh_paths))
n_species <- length(aoh_paths)

# Define output paths
raster_path <- c()
change_map_path <- c()
df_conn_score_path <- c()
path_SHS_tidy <- c()
path_SHS <- c()
path_SHS_timeseries <- c()
df_area_score_path <- c()

# Perform calculations for each species
for (s in 1:n_species) {
  print("========== Filtering by habitat type... ==========")
  ## This step creates land cover rasters only for the habitats of interest and masks by the species area of habitat ##
  species_aoh <- rast(aoh_paths[s])
  species_name <- species_names[s]

  layers_with_mask <- list()
  layers_nomask <- list()

  for (i in 1:2) {
    layer <- layers[[i]]

    if (length(habitats) > 0) {
      # Only keeps habitats specified in the inputs
      layer[!(layer[] %in% habitats)] <- NA
    }

    # Resample land cover raster to match area of habitat
    layer <- resample(layer, species_aoh, method = "near")

    # Need raster without mask for later analysis
    layers_nomask[[i]] <- layer

    # Crop to area of habitat of species
    layer <- crop(layer, species_aoh)

    # Mask using AOH
    layer <- mask(layer, species_aoh)

    # Store processed layer
    layers_with_mask[[i]] <- layer
  }

  # Combine layers into one raster
  land_cover_raster <- rast(layers_with_mask) # Land cover raster with aoh mask
  raster_nomask <- rast(layers_nomask) # Land cover raster without aoh mask

  # Save rasters
  raster_path[s] <- file.path(outputFolder, paste0(species_name, "_raster.tif"))
  writeRaster(land_cover_raster, filename = raster_path[s], overwrite = TRUE)

  print(sprintf("========== Measuring habitat change for %s... ==========", species_name))
  ## This step creates a raster that maps habitat gain, loss, and unchanged throughout the time interval ##

  # Split raster into layers
  r1 <- layers_with_mask[[1]]
  r2 <- layers_with_mask[[2]]

  # Convert habitat raster to binary values (4 = habitat, NA = no habitat)
  r1_bin <- r1
  r1_bin[!is.na(r1_bin)] <- 4
  r2_bin <- r2
  r2_bin[!is.na(r2_bin)] <- 4

  # Single raster that shows loss, gain and no change
  change_map <- r1_bin
  change_map[] <- NA
  change_map[r1_bin == 4 & (is.na(r2_bin) | r2_bin != 4)] <- 1 # Habitat loss
  change_map[(is.na(r1_bin) | r1_bin != 4) & r2_bin == 4] <- 2 # Habitat gain
  change_map[(r1_bin == 4 & r2_bin == 4)] <- 3 # No change

  # Write change map raster to file path
  change_map_path[s] <- file.path(outputFolder, paste0(species_name, "_habitat_change_map.tif"))

  writeRaster(
    change_map,
    filename = change_map_path[s],
    overwrite = TRUE
  )
  print(sprintf("========== Calculating area score for %s... ==========", species_name))
  ## This step calculates the species area score by finding the amount of area lost over time ##

  # Convert 4s to 1s for easier analysis
  r1[!is.na(r1)] <- 1
  r2[!is.na(r2)] <- 1

  full_raster <- c(r1, r2)

  # Calculate pixel area
  if (crs(full_raster, proj = TRUE) == "EPSG:4326") {
    cell_area <- cellSize(full_raster[[1]], unit = "ha")
  } else {
    spatial_res <- res(full_raster)[1]
    area_m2 <- (spatial_res^2) / 1000
    cell_area <- full_raster[[1]]
    cell_area[] <- area_m2
  }

  # Multiply habitat cover by pixel area
  s_habitat_area <- full_raster * cell_area

  # Sum habitat area per layer
  habitat_area <- global(s_habitat_area, sum, na.rm = TRUE)

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

  # Save table as TSV
  df_area_score_path[s] <- file.path(outputFolder, paste0(species_name, "_df_area_score.tsv"))
  write_tsv(df_area_score, df_area_score_path[s])

  print(sprintf("========== Calculating connectivity score for %s... ==========", species_name))
  ## This step calculates connectivity score by measuring how far each pixel is from the habitat edge ##

  # Need unmasked land cover as reference point
  r1_nomask <- ifel(!is.na(raster_nomask[[1]]), 1, 0)
  r2_nomask <- ifel(!is.na(raster_nomask[[2]]), 1, 0)

  full_raster_nomask <- c(r1_nomask, r2_nomask)

  # Calculate distance to edge
  l_habitat_dist <- map(as.list(full_raster_nomask), ~ gridDist(.x, target = 0))

  # Mask by species aoh
  s_habitat_dist <- mask(rast(l_habitat_dist), full_raster, maskvalues = 1, inverse = T)

  # Keep mean distance for each time point
  df_habitat_dist <- global(s_habitat_dist, mean, na.rm = T)

  # Create a connectivity score table
  df_conn_score <- tibble(sci_name = species_name, Year = c(start_year, end_year), value = df_habitat_dist$mean) |>
    mutate(ref_value = first(value)) |>
    dplyr::group_by(Year) |>
    mutate(diff = ref_value - value, percentage = (value * 100) / ref_value, score = "CS")
  df_conn_score

  # Save table as TSV
  df_conn_score_path[s] <- file.path(outputFolder, paste0(species_name, "_df_conn_score.tsv"))
  write_tsv(df_conn_score, df_conn_score_path[s])

  print(sprintf("========== Calculating species habitat score for %s... ==========", species_name))
  ## This step calculates the species habitat score (SHS) by taking the average between the connectivity and area scores ##

  # Make a summary table with AS and CS percentages
  df_SHS <- data.frame(sci_name = species_name, AS = as.numeric(df_area_score$percentage), CS = df_conn_score$percentage)

  # Add species habitat score to table
  df_SHS <- df_SHS |> dplyr::mutate(SHS = (AS + CS) / 2, info = "ESA", Year = c(start_year, end_year))

  # Long format of this table
  df_SHS_tidy <- df_SHS |> pivot_longer(c("AS", "CS", "SHS"), names_to = "Score", values_to = "Values")

  # Save tables as TSVs
  path_SHS_tidy[s] <- file.path(outputFolder, paste0(species_name, "_SHS_table_tidy.tsv"))
  write_tsv(df_SHS_tidy, path_SHS_tidy[s])

  colnames(df_SHS) <- c("Species", "Area Score", "Connectivity Score", "Species Habitat Score", "Source", "Year")
  path_SHS[s] <- file.path(outputFolder, paste0(species_name, "_SHS_table.tsv"))
  write_tsv(df_SHS, path_SHS[s])

  # Create a time series for SHS, AS, and CS
  SHS_timeseries <- ggplot(df_SHS_tidy, aes(x = Year, y = Values, col = Score)) +
    geom_line(linewidth = 1) +
    geom_point() +
    scale_y_continuous(breaks = seq(0, 110, 20)) +
    theme_bw() +
    scale_colour_brewer(palette = "Dark2") +
    coord_cartesian(ylim = c(0, 110)) +
    ylab("Connectivity Score (CS), Habitat Score (HS), \n Species Habitat Score (SHS)")

  # Save plot as png
  path_SHS_timeseries[s] <- file.path(outputFolder, paste0(species_name, "_SHS_timeseries.png"))
  ggsave(path_SHS_timeseries[s], SHS_timeseries, dpi = 300, width = 8, height = 5)
}

# Output results
biab_output("shs_timeseries", path_SHS_timeseries)
biab_output("df_shs", path_SHS)
biab_output("df_shs_tidy", path_SHS_tidy)
biab_output("raster", raster_path)
biab_output("habitat_change_map", change_map_path)
