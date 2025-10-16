#-------------------------------------------------------------------------------
# This script produces the base maps for the area of interest, based on the data for the species
#-------------------------------------------------------------------------------
options(timeout = max(60000000, getOption("timeout")))

packages <- list(
  "rjson", "dplyr", "tidyr", "purrr", "terra", "stars", "sf", "readr",
  "geodata", "gdalcubes", "rredlist", "stringr", "httr2", "geojsonsf", "rstac",
  "sp"
)

lapply(packages, library, character.only = TRUE)
path_script <- Sys.getenv("SCRIPT_LOCATION")

input <- biab_inputs()
print("Inputs: ")
print(input)

source(file.path(path_script, "data/filterCubeRangeFunc.R"), echo = TRUE)

# Parameters -------------------------------------------------------------------
# spatial resolution
spat_res <- ifelse(is.null(input$spat_res), 1000, input$spat_res)

# Define SRS
srs <- input$srs
check_srs <- grepl("^[[:digit:]]+$", srs)
sf_srs <- if (check_srs) st_crs(as.numeric(srs)) else st_crs(srs) # converts to numeric in case SRID is used
srs_cube <- suppressWarnings(if (check_srs) {
  authorities <- c("EPSG", "ESRI", "IAU2000", "SR-ORG")
  auth_srid <- paste(authorities, srs, sep = ":")
  auth_srid_test <- map_lgl(auth_srid, ~ !"try-error" %in% class(suppressWarnings(try(st_crs(.x), silent = TRUE))))
  if (sum(auth_srid_test) != 1) print("--- Please specify authority name or provide description of the SRS ---") else auth_srid[auth_srid_test]
} else {
  srs
}) # paste Authority in case SRID is used

# Define area of interest, country or region
study_area_path <- ifelse(is.null(input$study_area), NA, input$study_area)
country <- ifelse(is.null(input$country_region_polygon), NA, input$country_region_polygon)

# Size of buffer around study area
buff_size <- ifelse(is.null(input$buff_size), NA, input$buff_size)

# Define species
sp <- input$species

# Range map option
range_map_type <- ifelse(is.null(input$range_map_type), NA, input$range_map_type)
# Define expert range maps
sf_range_map_path <- if (is.null(input$sf_range_map)) {
  NA
} else {
  input$sf_range_map
}
r_range_map_path <- if (is.null(input$r_range_map)) {
  NA
} else {
  input$r_range_map
}

# Elevation_filter
elevation_filter <- ifelse(input$elevation_filter == "Yes", 1, 2)
# Buffer for elevation values
elev_buffer <- ifelse(is.null(input$elev_buffer), 0, input$elev_buffer)

# credentials
token <- Sys.getenv("IUCN_TOKEN")
if (token == "") {
  biab_error_stop("Please specify an IUCN token in your environment file runner.env")
}

#-------------------------------------------------------------------------------
# Step 1 - Get study area
#-------------------------------------------------------------------------------

if (!is.na(study_area_path)) {
  print("Using a custom study area file...")
  sf_area_lim1 <- st_read(study_area_path) # user defined area
} else if (!is.na(country)) {
  print("Using a country polygon as the study area...")
  sf_area_lim1 <- st_read(country) |> st_make_valid()
}
if (is.na(study_area_path) && is.na(country)) {
  biab_error_stop("A study area is required, please either enter a country/region or a custom study area")
}

sf_area_lim1_srs <- sf_area_lim1 |> st_transform(sf_srs)
area_study_a <<- sf_area_lim1_srs |> st_area()

print("==================== Step 1 - Study area loaded =====================")

#-------------------------------------------------------------------------------
# Step 2 -  Get area of habitat
#-------------------------------------------------------------------------------
v_path_to_area_of_habitat <- c()
v_path_bbox_analysis <- c()
df_aoh_areas <- tibble()

for (i in seq_along(sp)) {
  print(sprintf("Finding the area of habitat for %s", sp[i]))
  if (!dir.exists(file.path(outputFolder, sp[i]))) {
    dir.create(file.path(outputFolder, sp[i]))
  } else {
    print("dir exists")
  }

  # Get range map---------------------------------------------------------------
  sf_range_map <<- st_read(sf_range_map_path[i])
  if (range_map_type == "Polygon") {
    sf_range_map <<- st_read(sf_range_map_path[i])
  }
  if (range_map_type == "Raster") {
    r_range_map <- rast(r_range_map_path[i])
    sf_range_map <<- as.polygons(ifel(r_range_map == 1, 1, NA)) |> st_as_sf()
  }
  if (range_map_type == "Both") {
    sf_range_map <<- st_read(sf_range_map_path[i])
    r_range_map <- rast(r_range_map_path[i])
    r_range_map2 <- project(r_range_map, crs(sf_range_map), method = "near")
    r_range_map2 <- terra::mask(terra::crop(r_range_map2, sf_range_map), sf_range_map)
    sf_range_map <<- as.polygons(ifel(r_range_map2 == 1, 1, NA)) |> st_as_sf()
  }

  sf_area_lim2 <- sf_range_map |>
    st_make_valid() |>
    st_transform(st_crs(sf_area_lim1))

  sf_area_lim2_srs <- sf_area_lim2 |>
    st_transform(sf_srs) |>
    st_buffer(0)

  area_range_map <- sf_area_lim2_srs |>
    st_combine() |>
    st_combine() |>
    st_area()

  print("========== Step 2.1 - Expert range map successfully loaded ==========")

  # Intersect range map to study area-------------------------------------------
  # sf_area_lim <- st_intersection(sf_area_lim2,sf_area_lim1) |>
  #   st_make_valid()
  print(st_crs(sf_area_lim2_srs) == st_crs(sf_area_lim1_srs))
  sf_area_lim_srs <- st_intersection(sf_area_lim2_srs, sf_area_lim1_srs) |>
    st_make_valid()

  print(sf_area_lim_srs)
  if (nrow(sf_area_lim_srs) == 0) {
    stop(paste0(sp[i], " range does not fall within chosen study area"))
  }
  # define buffer size
  if (is.na(buff_size)) {
    # Buffer size for range map
    sf_bbox_aoh <- sf_area_lim_srs |>
      st_bbox() |>
      st_as_sfc()
    area_bbox <- sf_bbox_aoh |> st_area()
    buff_size <- round(sqrt(area_bbox) / 2)
  } else {
    buff_size <- buff_size
  }

  # get bounding box for the complete area projected and non projected----------
  suppressWarnings({
    if (!is.null(st_crs(sf_area_lim_srs)$units)) {
      sf_ext_srs <<- st_bbox(st_buffer(sf_area_lim_srs, buff_size))
    } else {
      sf::sf_use_s2(FALSE)
      sf_ext_srs <<- st_bbox(st_buffer(sf_area_lim_srs, buff_size))
      message("--- Buffer defined for spherical geometry ---")
    }
  })
  print(sf_ext_srs)

  sf_bbox_analysis <- sf_ext_srs |> st_as_sfc()
  area_bbox_analysis <- sf_bbox_analysis |> st_area()

  v_path_bbox_analysis[i] <- file.path(outputFolder, sp[i], paste0(sp[i], "_st_bbox.gpkg"))
  st_write(sf_bbox_analysis, v_path_bbox_analysis[i], append = F)

  print("================== Step 2.2 - Bounding box created =================")

  # Create raster
  r_frame <- rast(terra::ext(sf_ext_srs), resolution = spat_res)

  crs(r_frame) <- srs_cube
  values(r_frame) <- 1
  r_aoh <- terra::mask(r_frame, vect(as(sf_area_lim_srs, "Spatial")))

  # elevation filters-----------------------------------------------------------
  if (elevation_filter == 1) {
    parts <- strsplit(sp[i], " ")[[1]]
    gn <- parts[1]
    spe <- parts[2]
    subvar <- NULL

    if (length(parts) >= 4 && parts[3] %in% c("ssp.", "subsp.", "var.")) {
      subvar <- parts[4]
    }
    # Load elevation preferences
    df_IUCN_sheet <- rredlist::rl_species_latest(
      genus = gn,
      species = spe,
      infra = subvar,
      key = token
    )$supplementary_info

    if (length(df_IUCN_sheet$lower_elevation_limit) == 0) {
      df_IUCN_sheet$lower_elevation_limit <- 0
    }
    if (length(df_IUCN_sheet$upper_elevation_limit) == 0) {
      df_IUCN_sheet$upper_elevation_limit <- 0
    }

    df_IUCN_sheet <- data.frame(
      lower_elevation_limit = as.numeric(df_IUCN_sheet$lower_elevation_limit),
      upper_elevation_limit = as.numeric(df_IUCN_sheet$upper_elevation_limit)
    )

    if (is.null(dim(df_IUCN_sheet))) {
      stop(paste0(sp[i], " not found in IUCN database. Check name and spelling."))
    }

    df_IUCN_sheet_condition <- df_IUCN_sheet |> dplyr::mutate(
      min_elev = case_when( # evaluate if elevation ranges exist and add margin if included
        is.na(lower_elevation_limit) ~ NA_real_,
        !is.na(lower_elevation_limit) & (as.numeric(lower_elevation_limit) < elev_buffer) ~ 0,
        !is.na(lower_elevation_limit) & (as.numeric(lower_elevation_limit) >= elev_buffer) ~ as.numeric(lower_elevation_limit) - elev_buffer
      ),
      max_elev = case_when(
        is.na(upper_elevation_limit) ~ NA_real_,
        !is.na(upper_elevation_limit) ~ as.numeric(upper_elevation_limit) + elev_buffer
      )
    )

    print(df_IUCN_sheet_condition |> select(lower_elevation_limit, upper_elevation_limit))

    with(df_IUCN_sheet_condition, if (is.na(min_elev) & is.na(max_elev)) { # if no elevation values are provided then the range map stays the same
      r_aoh <<- terra::wrap(r_aoh)
    } else { # at least one elevation range exists then create cube_STRM to filter according to elevation ranges
      # STRM from Copernicus
      cube_STRM <- terra::rast(c(input$rasters))

      # Extract layers
      elev_min <- cube_STRM[[1]]
      elev_max <- cube_STRM[[2]]

      # Create a logical mask: TRUE (1) where both conditions are satisfied, NA elsewhere
      mask <- elev_min >= min_elev & elev_max <= max_elev

      # Resample mask to match r_aoh resolution (if needed)
      r_STRM_range_res <- terra::resample(mask, r_aoh) # or "bilinear" if needed

      # Apply mask: crop + mask + wrap to finalize filtered area
      r_aoh <<- terra::wrap(
        terra::mask(
          terra::crop(r_aoh, r_STRM_range_res),
          r_STRM_range_res
        )
      )

      print("============= Step 2.2.1 - Filter by elevation limits ==============")
    })
  }
  r_aoh <- terra::unwrap(r_aoh)
  v_path_to_area_of_habitat[i] <- file.path(outputFolder, sp[i], paste0(sp[i], "_r_aoh.tif"))
  dir.create(dirname(v_path_to_area_of_habitat[i]), recursive = TRUE, showWarnings = FALSE)
  terra::writeRaster(r_aoh, filename = v_path_to_area_of_habitat[i], overwrite = TRUE)

  print("================== Step 2.3 - Area of habitat created =================")

  # get area for the area of habitat delimited by the study area or country
  r_aoh_area <- terra::cellSize(r_aoh, unit = "ha") # create raster of areas by pixel
  area_aoh <- global(r_aoh_area, sum)$sum

  # create dataframe with area values--------------------------------------------
  df_aoh_areas_sp <- tibble(
    sci_name = sp[i], area_range_map = area_range_map,
    area_study_a = area_study_a, area_bbox_analysis = area_bbox_analysis,
    buff_size = buff_size, area_aoh = area_aoh
  )
  write_tsv(df_aoh_areas_sp, file.path(outputFolder, sp[i], paste0(sp[i], "_df_aoh_areas.tsv")))

  df_aoh_areas <- bind_rows(df_aoh_areas, df_aoh_areas_sp)
  print("================== Step 2.4 - Table of areas =================")
}

path_aoh_areas <- file.path(outputFolder, "df_aoh_areas.tsv")
write_tsv(df_aoh_areas, file = path_aoh_areas)


# Outputing result -----------------------------------------------------
biab_output("r_area_of_habitat", v_path_to_area_of_habitat)
biab_output("sf_bbox", v_path_bbox_analysis)
biab_output("df_aoh_areas", path_aoh_areas)
