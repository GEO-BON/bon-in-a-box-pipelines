# These packages are not on Anaconda, so we install them from CRAN or GitHub
biab_ensure_package(
    "samc", # required by Makurhini
    installer = function() {
        install.packages(c("samc"), dependencies=FALSE);
    }
)

biab_ensure_package(
    "graph4lg", # required by Makurhini
    installer = function() {
        install.packages(c("graph4lg"), dependencies=FALSE);
    }
)

biab_ensure_package(
    "Makurhini",
    installer = function() {
        remotes::install_github("connectscape/Makurhini@1dc5bd3ce9f141656f058778eac0cb08a166269e", dependencies = FALSE)
    }
)


# Script for analyzing ProtConn with the function
packages_list <- list("sf", "terra", "tidyverse", "ggrepel", "rjson", "Makurhini", "PROJ")

# Load libraries
lapply(packages_list, library, character.only = TRUE) # Load libraries - packages

sf_use_s2(FALSE) # turn off spherical geometry

input <- biab_inputs() # Load input file
crs_input <- paste0(input$crs$CRS$authority, ":", input$crs$CRS$code)
if (is.lonlat(crs_input)) {
  biab_error_stop(sprintf("The current CRS %s is in latitude longitude. Please choose a projected crs.", crs_input))
}

if ((input$year_int) >= (input$years - input$start_year)) {
  biab_error_stop("Please make sure the year interval is smaller than the difference between start year and year for cutoff.")
}

units::units_options(set_units_mode = "standard")
protected_areas_path <- c()
# Load study area shapefile
print("Step: loading study area")

if (length(input$study_area_polygon) > 1) { # if there is userdata study area input then use that
  study_area_path <- input$study_area_polygon[grepl("/userdata", input$study_area_polygon)]
  print(paste("Study area file:", study_area_path))
  study_area <- st_read(study_area_path)
} else {
  study_area <- st_read(input$study_area_polygon) # otherwise use the country polygon from the script
}


study_area <- st_transform(study_area, st_crs(crs_input))
print(paste("Study area reprojected to", crs_input))

# check if there is WDPA data
protected_areas <- input$protected_area_polygon[grepl("protected_areas_clean", input$protected_area_polygon)]

# check if there is user data
protected_areas_user <- input$protected_area_polygon[grepl("/userdata", input$protected_area_polygon)]

if (length(protected_areas_user) > 0 && length(protected_areas) > 0) {
  print("Protected area source: WDPA and user input")
  pa_input_type <- "Both"
} else if (length(protected_areas_user) > 0) {
  print("Protected area source: user input only")
  pa_input_type <- "User input"
} else if (length(protected_areas) > 0) {
  print("Protected area source: WDPA only")
  pa_input_type <- "WDPA"
} else {
  biab_error_stop("No files found: Please input or choose protected areas")
}

### Load protected area shapefile
if (pa_input_type == "WDPA" || pa_input_type == "Both") { # if using WDPA data, load that

  protected_areas <- st_read(protected_areas)
  protected_areas <- st_transform(protected_areas, st_crs(crs_input))

  print(paste("Loaded", nrow(protected_areas), "WDPA protected areas"))

  if (input$time_series == TRUE) {
    # label which rows are missing dates to remove later
    if (input$include_na_dates == FALSE) {
      protected_areas_NA <- which(
        is.na(protected_areas$STATUS_YR) |
          protected_areas$STATUS_YR == 0
      )
    }

    # Assign all PAs without a date to the start year for the time series or omit
    for (i in 1:nrow(protected_areas)) {
      if (is.na(protected_areas$STATUS_YR[i]) | protected_areas$STATUS_YR[i] == 0) {
        protected_areas$STATUS_YR[i] <- input$start_year
      }
    }

    protected_areas$STATUS_YR <- lubridate::parse_date_time(protected_areas$STATUS_YR, orders = c("ymd", "mdy", "dmy", "y"))
    protected_areas$STATUS_YR <- lubridate::year(protected_areas$STATUS_YR)
  }
}


if (pa_input_type == "User input" || pa_input_type == "Both") { # rename and parse date column
  protected_areas_user <- st_read(protected_areas_user) # load
  print(paste("Loaded", nrow(protected_areas_user), "user-defined protected areas"))
  protected_areas_user <- st_transform(protected_areas_user, st_crs(crs_input))

  if (input$time_series == TRUE) {
    if (is.null(input$date_column)) {
      biab_error_stop("Please specify a date column name for the protected areas file or deselect the time series option.")
    }

    if (!is.null(input$date_column)) {
      # Assign all PAs without a date to the start year for the time series
      print("Step: assigning start year to user protected areas without a date")

      protected_areas_user <- protected_areas_user %>% rename(STATUS_YR = input$date_column)
      for (i in 1:nrow(protected_areas_user)) {
        if (is.na(protected_areas_user$STATUS_YR[i]) | protected_areas_user$STATUS_YR[i] == 0) {
          protected_areas_user$STATUS_YR[i] <- input$start_year
        }
      }

      protected_areas_user$STATUS_YR <- lubridate::parse_date_time(protected_areas_user$STATUS_YR, orders = c("ymd", "mdy", "dmy", "y"))
      protected_areas_user$STATUS_YR <- lubridate::year(protected_areas_user$STATUS_YR)
    }
  }
}


if (pa_input_type == "User input") {
  protected_areas <- protected_areas_user
}

if (pa_input_type == "Both") {
  if (!"geom" %in% names(protected_areas)) { # check that geom column exists
    biab_error_stop("Geometry column must be called 'geom'")
  }
  print("Step: combining user-defined protected areas with WDPA data")
  if (input$time_series == TRUE) {
    protected_areas <- protected_areas[, c("STATUS_YR", "geom")]
    protected_areas_user <- protected_areas_user[, c("STATUS_YR", "geom")]
  } else {
    protected_areas <- protected_areas[, c("geom")]
    protected_areas_user <- protected_areas_user[, c("geom")]
  }

  protected_areas <- rbind(protected_areas, protected_areas_user)
}

print(paste("Protected area geometry types:", paste(unique(st_geometry_type(protected_areas)), collapse = ", ")))
print(paste("Total protected areas loaded:", nrow(protected_areas)))
print("Step: fixing invalid protected area geometries")
# buffer by a distance of 0 to fix some geometries
protected_areas <- st_buffer(protected_areas, 0)

any_invalid <- any(!st_is_valid(protected_areas))
if (any_invalid) {
  print("Invalid geometries detected, repairing them")
  protected_areas <- st_make_valid(protected_areas)
}

## Make function to get rid of overlapping geometries
dissolve_overlaps <- function(x) {
  print("Step: dissolving overlapping protected areas")

  protected_areas_clean <- x %>%
    st_buffer(dist = 10) %>%
    st_union() %>%
    st_cast("POLYGON") %>%
    st_as_sf()

  # Re-validate after union if needed
  invalid_after_union <- sum(!st_is_valid(protected_areas_clean))
  if (invalid_after_union > 0) {
    print(paste(invalid_after_union, "invalid geometries found after union, repairing them"))
    protected_areas_clean <- st_make_valid(protected_areas_clean)
  }

  # Cast all to POLYGON (handles both POLYGON and MULTIPOLYGON)
  protected_areas_clean <- protected_areas_clean %>%
    st_cast("POLYGON", group_or_split = TRUE)

  # Checks to see if st_cast causes polygon loss
  # Before
  n_before <- nrow(protected_areas_clean)

  protected_areas_clean <- protected_areas_clean %>%
    st_cast("POLYGON", group_or_split = TRUE)

  # After
  n_after <- nrow(protected_areas_clean)
  if (n_after < n_before) {
    warning(paste(
      "Polygon loss detected:", n_before - n_after,
      "features lost during st_cast"
    ))
  } else {
    print(paste("Dissolved into", n_after, "separate polygons"))
  }

  # Re-validate after cast if needed
  invalid_after_cast <- sum(!st_is_valid(protected_areas_clean))
  if (invalid_after_cast > 0) {
    print(paste(invalid_after_cast, "invalid geometries found after cast, repairing them"))
    protected_areas_clean <- st_make_valid(protected_areas_clean)
  }

  return(protected_areas_clean)
}

############## CALCULATE PROTCONN ##################

print("Step: calculating ProtConn")

if ("STATUS_YR" %in% names(protected_areas)) {
  protected_areas <- protected_areas %>% filter(STATUS_YR <= input$years | is.na(STATUS_YR))
}
print(paste("Protected areas within the selected years:", nrow(protected_areas)))

# Get rid of overlaps
protected_areas_simp <- dissolve_overlaps(protected_areas)

# rename geometry column
sf::st_geometry(protected_areas_simp) <- "geom"

print(paste("Protected areas after dissolving overlaps:", nrow(protected_areas_simp)))

# Filter out protected areas smaller than the size threshold
threshold <- units::set_units(input$pa_size_threshold, "m^2")
protected_areas_simp <- protected_areas_simp %>% filter((st_area(protected_areas_simp)) > threshold)
print(paste("Protected areas larger than", input$pa_size_threshold, "m2:", nrow(protected_areas_simp)))

# output simplified protected areas
protected_areas_simp_path <- file.path(outputFolder, "protected_areas_full.gpkg")
sf::st_write(protected_areas_simp, protected_areas_simp_path, delete_dsn = T)

if (nrow(protected_areas_simp) < 2) {
  biab_error_stop("Can't calculate ProtConn on one or less protected areas, please check input file.")
}

if (isTRUE(st_is_longlat(protected_areas_simp))) {
  biab_error_stop("Protected areas are in latitude longitude degrees, please choose a projected coordinate reference system.")
}

protconn_result <- tryCatch(
  {
    Makurhini::MK_ProtConn(
      nodes = protected_areas_simp,
      region = study_area,
      area_unit = "m2",
      distance = list(type = "edge", keep = 0.6),
      probability = 0.5,
      transboundary = input$buffer,
      distance_thresholds = c(input$distance_threshold),
      protconn_bound = TRUE
    )
  },
  error = function(e) {
    if (grepl("missing value where TRUE/FALSE needed", e$message)) {
      biab_error_stop("Error - PAs are functionally isolated at this dispersal threshold. Please input a larger dispersal threshold or check the protected area input file.")
    }
  }
)
gc()

# extract columns of interest and put in a dataframe, add a distance column
protconn_result_list <- list()

# make sure the result is a list

# need to coerce into a list if it is only one
if (length(input$distance_threshold) == 1) {
  name <- paste0("d", input$distance_threshold)
  tmp <- protconn_result
  protconn_result <- list()
  protconn_result[[name]] <- tmp
}

study_area_km2 <- round((as.numeric(as.data.frame(protconn_result[[1]])[3, 2])) / 1e6, 2)
biab_output("study_area_km2", study_area_km2)
protected_area_km2 <- round((as.numeric(as.data.frame(protconn_result[[1]])[4, 2]) / 1e6), 2)
biab_output("protected_area_km2", protected_area_km2)

for (i in seq_along(protconn_result)) {
  protconn <- as.data.frame(protconn_result[[i]])
  df <- protconn %>%
    dplyr::filter(`ProtConn indicator` %in% c("Prot", "Unprotected", "ProtConn", "ProtUnconn", "ProtConn_Within", "ProtConn_Contig", "ProtConn_Unprot")) %>%
    dplyr::select(Percentage, `ProtConn indicator`)
  df$Distance <- names(protconn_result)[i]
  df <- mutate(df, Distance = as.numeric(gsub("^d", "", Distance)))
  protconn_result_list[[i]] <- df
}

# bind list
protconn_result_long <- do.call(rbind, protconn_result_list)
print("ProtConn results:")
print(protconn_result_long)
# turn to wide format for output
protconn_result <- pivot_wider(protconn_result_long, id_cols = "Distance", names_from = "ProtConn indicator", values_from = "Percentage")

# output
protconn_result_path <- file.path(outputFolder, "protconn_result.csv")
write.csv(protconn_result, protconn_result_path, row.names = F)
biab_output("protconn_result", protconn_result_path)

protconn_result_long_noprot <- protconn_result_long %>% filter(`ProtConn indicator` %in% c("Unprotected", "ProtConn", "ProtUnconn")) # filter out protected for plotting
result_plot <- ggplot2::ggplot(protconn_result_long_noprot) +
  geom_col(aes(y = Percentage, x = 1, fill = `ProtConn indicator`)) +
  coord_polar(theta = "y") +
  xlim(c(0, 1.5)) +
  geom_text_repel(
    aes(y = Percentage, x = 1, group = `ProtConn indicator`, label = paste0(round(Percentage, 2), "%")),
    position = position_stack(vjust = 0.5)
  ) +
  scale_fill_manual(values = c("#1F968BFF", "#73D055FF", "grey60")) +
  theme_void() +
  facet_wrap(~Distance) +
  theme(text = element_text(color = "black"))

# output result plot
result_plot_path <- file.path(outputFolder, "result_plot.png") # save protconn result
ggsave(result_plot_path, result_plot, dpi = 300, height = 7, width = 7)
biab_output("result_plot", result_plot_path)


# Change in protection over time
# Sequence with start year by interval

years <- seq(from = input$start_year, to = input$years, by = input$year_int)
if (!(input$years %in% years)) { # check if the end year is there
  # 3. If not, append it to the sequence and ensure uniqueness and order
  years <- sort(unique(c(years, input$years)))
}

# Calculate ProtConn for each specified year
print("Step: calculating ProtConn time series")

if (input$time_series == TRUE) {
  # drop Na dates if user chose not to include them
  if (input$include_na_dates == FALSE) {
    protected_areas <- protected_areas[-protected_areas_NA, ]
  }
  protconn_ts_result <- list()

  for (i in seq_along(years)) {
    yr <- years[i]
    print(paste0("Step: processing year ", yr, " (", i, "/", length(years), ")"))


    if (input$include_na_dates == TRUE && yr == input$years) { # skip end year because already calculated above
      protconn_result_combined <- protconn_result_long
      protconn_result_combined$Year <- yr
    } else {
      protected_areas_filt_yr <- protected_areas %>%
        dplyr::filter(STATUS_YR <= yr)

      if (nrow(protected_areas_filt_yr) < 2) {
        print(paste("Not enough protected areas in", yr, "(need at least 2), skipping year"))
        next
      }

      protected_areas_filt_yr <- dissolve_overlaps(protected_areas_filt_yr)
      protected_areas_filt_yr <- protected_areas_filt_yr %>% filter((st_area(protected_areas_filt_yr)) > threshold)
      print(paste0("Protected areas in ", yr, " larger than ", input$pa_size_threshold, " m2: ", nrow(protected_areas_filt_yr)))

      protconn_result_yrs <- Makurhini::MK_ProtConn(
        nodes = protected_areas_filt_yr,
        region = study_area,
        area_unit = "m2",
        distance = list(type = "edge", keep = 0.6),
        probability = 0.5,
        transboundary = input$buffer,
        distance_thresholds = c(input$distance_threshold),
        protconn_bound = TRUE
      )


      if (length(input$distance_threshold) == 1) {
        name <- paste0("d", input$distance_threshold)
        tmp <- protconn_result_yrs
        protconn_result_yrs <- list()
        protconn_result_yrs[[name]] <- tmp
      }

      # Reset for this iteration to avoid duplicates
      protconn_result_list <- list()

      for (j in seq_along(protconn_result_yrs)) {
        protconn <- as.data.frame(protconn_result_yrs[[j]])
        df <- protconn %>%
          dplyr::filter(`ProtConn indicator` %in% c("Prot", "Unprotected", "ProtConn", "ProtUnconn", "ProtConn_Within", "ProtConn_Contig", "ProtConn_Unprot")) %>%
          dplyr::select(Percentage, `ProtConn indicator`)
        df$Distance <- as.numeric(gsub("^d", "", names(protconn_result_yrs)[j]))
        protconn_result_list[[j]] <- df
      }

      protconn_result_combined <- do.call(rbind, protconn_result_list)
      protconn_result_combined$Year <- yr
    }
    print(paste("ProtConn results for", yr))
    print(protconn_result_combined)
    protconn_ts_result[[i]] <- protconn_result_combined
    if (exists("protected_areas_filt_yr")) {
      protected_areas_path[i] <- file.path(outputFolder, paste0(yr, "_protected_areas.gpkg"))
      sf::st_write(protected_areas_filt_yr, protected_areas_path[i], delete_dsn = T)
    }
    gc()
  }
  protected_areas_path <- c(protected_areas_simp_path, protected_areas_path) # combine the original simplified protected areas with the yearly filtered ones for output


  # Final time series dataframe
  protconn_result_yrs <- do.call(rbind, protconn_ts_result)
  print("ProtConn time series results:")
  print(protconn_result_yrs)

  result_yrs <- tidyr::pivot_wider(
    data = protconn_result_yrs,
    id_cols = c("Distance", "Year"),
    names_from = "ProtConn indicator",
    values_from = "Percentage",
    id_expand = TRUE
  )

  result_yrs_path <- file.path(outputFolder, "result_yrs.csv") # save protconn result
  write.csv(result_yrs, result_yrs_path)
  biab_output("result_yrs", result_yrs_path)

  xint <- (input$start_year) + round(((input$years - input$start_year) / 2))

  protconn_result_yrs <- protconn_result_yrs %>% filter(`ProtConn indicator` %in% c("Unprotected", "ProtConn", "ProtUnconn")) # filter out unprotected for plotting

  # make separate plot for each distance threshold
  plot_paths <- c()
  for (i in seq_along(input$distance_threshold)) {
    result_dist <- protconn_result_yrs %>% filter(Distance == input$distance_threshold[i])

    name <- paste("Median dispersal distance", input$distance_threshold[i], "meters")
    result_yrs_plot <-
      ggplot(
        result_dist,
        aes(x = Year, y = Percentage, group = `ProtConn indicator`, shape = `ProtConn indicator`, color = `ProtConn indicator`)
      ) +
      geom_point() +
      geom_line() +
      labs(y = "Percent area", x = "Year", title = name) +
      scale_color_manual(values = c("#39568CFF", "#1F968BFF", "#73D055FF")) +
      geom_hline(yintercept = 30, lty = 2) +
      annotate("text", x = xint, y = 33, label = "Kunming-Montreal target") +
      facet_wrap(~Distance) +
      theme_classic() +
      theme(strip.text.y = element_blank())

    file_path <- file.path(outputFolder, paste0("result_plot_yrs_", input$distance_threshold[i], "m.png"))
    plot_paths <- c(plot_paths, file_path) # put file paths in list
    ggsave(file_path, result_yrs_plot)
  }
  biab_output("result_yrs_plot", plot_paths)
} else {
  result_yrs <- NULL
  biab_output("result_yrs", result_yrs)

  result_yrs_plot <- NULL
  biab_output("result_yrs_plot", result_yrs_plot)

  protected_areas_path <- protected_areas_simp_path
}

biab_output("protected_areas", protected_areas_path[!is.na(protected_areas_path)])
