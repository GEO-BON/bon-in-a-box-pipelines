# Script for analyzing ProtConn with the function

packages_list <- list("sf", "terra", "tidyverse", "ggrepel", "rjson", "Makurhini", "PROJ", "ggrepel")

# Load libraries
lapply(packages_list, library, character.only = TRUE) # Load libraries - packages

sf_use_s2(FALSE) # turn off spherical geometry

input <- biab_inputs() # Load input file
crs <- paste0(input$crs$CRS$authority, ":", input$crs$CRS$code)

if ((input$year_int) >= (input$years - input$start_year)) {
  biab_error_stop("Please make sure the year interval is smaller than the difference between start year and year for cutoff.")
}

units::units_options(set_units_mode = "standard")
# Load study area shapefile
print("Loading study area")

if (length(input$study_area_polygon) > 1) { # if there is userdata study area input then use that
  study_area_path <- input$study_area_polygon[grepl("/userdata", input$study_area_polygon)]
  print(study_area_path)
  study_area <- st_read(study_area_path)
} else {
  study_area <- st_read(input$study_area_polygon) # otherwise use the country polygon from the script
}

study_area <- st_transform(study_area, st_crs(crs))
print("CRS:")
print(st_crs(study_area))

# check if there is WDPA data
protected_areas <- input$protected_area_polygon[grepl("protected_areas_clean", input$protected_area_polygon)]

# check if there is user data
protected_areas_user <- input$protected_area_polygon[grepl("/userdata", input$protected_area_polygon)]

if (length(protected_areas_user) > 0 && length(protected_areas) > 0) {
  print("Using both WDPA and User input")
  pa_input_type <- "Both"
} else if (length(protected_areas_user) > 0) {
  print("Only using user input data")
  pa_input_type <- "User input"
} else if (length(protected_areas) > 0) {
  print("Using WDPA data")
  pa_input_type <- "WDPA"
} else {
  biab_error_stop("No files found: Please input or choose protected areas")
}

### Load protected area shapefile
if (pa_input_type == "WDPA" || pa_input_type == "Both") { # if using WDPA data, load that

  print(protected_areas)
  protected_areas <- st_read(protected_areas, type = 3, promote_to_multi = FALSE) # input as polygons
  protected_areas <- st_transform(protected_areas, st_crs(crs))
  # fix date
  protected_areas$legal_status_updated_at <- lubridate::parse_date_time(protected_areas$legal_status_updated_at, orders = c("ymd", "mdy", "dmy", "y"))
  protected_areas$legal_status_updated_at <- lubridate::year(protected_areas$legal_status_updated_at)

  print("Protected area geometry:")
  print(unique(st_geometry_type(protected_areas)))
}


if (pa_input_type == "User input" || pa_input_type == "Both") { # rename and parse date column
  protected_areas_user <- st_read(protected_areas_user, type = 3, promote_to_multi = FALSE) # load
  print(protected_areas_user)
  protected_areas_user <- st_transform(protected_areas_user, st_crs(crs))
  if (is.null(input$date_column)) {
    biab_error_stop("Please specify a date column name for the protected areas file.")
  }
  protected_areas_user <- protected_areas_user %>% rename(legal_status_updated_at = input$date_column)
  protected_areas_user$legal_status_updated_at <- lubridate::parse_date_time(protected_areas_user$legal_status_updated_at, orders = c("ymd", "mdy", "dmy", "y"))
  protected_areas_user$legal_status_updated_at <- lubridate::year(protected_areas_user$legal_status_updated_at)
}

if (pa_input_type == "User input") {
  protected_areas <- protected_areas_user
}

if (pa_input_type == "Both") {
  if (!"geom" %in% names(protected_areas)) { # check that geom column exists
    biab_error_stop("Geometry column must be called 'geom'")
  }
  print("Combining user defined protected areas with WDPA data")
  protected_areas <- protected_areas[, c("legal_status_updated_at", "geom")]
  protected_areas_user <- protected_areas_user[, c("legal_status_updated_at", "geom")]

  protected_areas <- rbind(protected_areas, protected_areas_user)
}

print(nrow(protected_areas))

protected_areas <- st_make_valid(protected_areas)

## Make function to get rid of overlapping geometries
dissolve_overlaps <- function(x) {
  print("Combining overlapping geometries")
  protected_areas_buffer <- st_buffer(x, dist = 10) # buffering polygons by 10 meters
  intersections <- st_intersects(protected_areas_buffer) # Identifying intersecting polygons

  # Grouping intersecting polygons
  groups <- as.integer(igraph::components(graph = igraph::graph_from_adj_list(intersections))$membership)

  x$group_id <- groups

  protected_areas_clean <- x %>%
    group_by(group_id) %>%
    summarize(geom = st_union(geom), .groups = "drop") # COmbining intersecting polygons

  # Exploding multipolygons into polygons for faster calculation
  protected_areas_multi <- protected_areas_clean %>%
    filter(st_geometry_type(protected_areas_clean) == "MULTIPOLYGON") %>%
    st_cast("POLYGON", group_or_split = TRUE)
  protected_areas_poly <- protected_areas_clean %>% filter(st_geometry_type(protected_areas_clean) == "POLYGON")

  protected_areas_clean <- rbind(protected_areas_multi, protected_areas_poly)

  return(protected_areas_clean)
}

############## CALCULATE PROTCONN ##################

print("Calculating ProtConn")

protected_areas <- protected_areas %>% filter(legal_status_updated_at <= input$years | is.na(legal_status_updated_at))
print("Num prot areas:")
print(nrow(protected_areas))
# Get rid of overlaps
protected_areas_simp <- dissolve_overlaps(protected_areas)
print("Num prot areas with overlaps dissolved and multipolygons expanded into different rows:")
print(nrow(protected_areas_simp))

# output simplified protected areas
protected_areas_simp_path <- file.path(outputFolder, "protected_areas.gpkg")
sf::st_write(protected_areas_simp, protected_areas_simp_path, delete_dsn = T)
biab_output("protected_areas", protected_areas_simp_path)


if (nrow(protected_areas_simp) < 2) {
  biab_error_stop("Can't calculate ProtConn on one or less protected areas, please check input file.")
}

if (isTRUE(st_is_longlat(protected_areas_simp))) {
  biab_error_stop("Protected areas are in latitude longitude degrees, please choose a projected coordinate reference system.")
}

protconn_result <- Makurhini::MK_ProtConn(
  nodes = protected_areas_simp,
  region = study_area,
  area_unit = "m2",
  distance = list(type = input$distance_matrix_type),
  probability = 0.5,
  transboundary = 0,
  distance_thresholds = c(input$distance_threshold)
)
gc()
print(class(protconn_result))
print(length(protconn_result))

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

print(names(protconn_result))
for (i in seq_along(protconn_result)) {
  protconn <- as.data.frame(protconn_result[[i]])
  print(protconn)
  df <- protconn %>%
    dplyr::filter(`ProtConn indicator` %in% c("Prot", "Unprotected", "ProtConn", "ProtUnconn")) %>%
    dplyr::select(Percentage, `ProtConn indicator`)
  df$Distance <- names(protconn_result)[i]
  df <- mutate(df, Distance = as.numeric(gsub("^d", "", Distance)))
  protconn_result_list[[i]] <- df
}

# bind list
protconn_result_long <- do.call(rbind, protconn_result_list)
print(protconn_result_long)
# turn to wide format for output
protconn_result <- pivot_wider(protconn_result_long, id_cols = "Distance", names_from = "ProtConn indicator", values_from = "Percentage")

# output
protconn_result_path <- file.path(outputFolder, "protconn_result.csv")
write.csv(protconn_result, protconn_result_path, row.names = F)
biab_output("protconn_result", protconn_result_path)

protconn_result_long_noprot <- protconn_result_long %>% filter(!`ProtConn indicator` == "Prot") # filter out protected for plotting
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
# assign all PAs with no date to the start date for plotting
for (i in 1:nrow(protected_areas)) {
  if (is.na(protected_areas$legal_status_updated_at[i])) {
    print("fixing date")
    protected_areas$legal_status_updated_at[i] <- input$start_year
  }
}

# Calculate ProtConn for each specified year
print("Calculating ProtConn time series")

protconn_ts_result <- list()

for (i in seq_along(years)) {
  yr <- years[i]
  print(paste("Processing year:", yr))

  if (yr == input$years) { # skip end year because already calculated above
    protconn_result_combined <- protconn_result_long
    protconn_result_combined$Year <- yr
  } else {
    protected_areas_filt_yr <- protected_areas %>%
      dplyr::filter(legal_status_updated_at <= yr)

    if (nrow(protected_areas_filt_yr) < 2) {
      message(paste("Not enough protected area data from", yr, "- skipping"))
      next
    }

    protected_areas_filt_yr <- dissolve_overlaps(protected_areas_filt_yr)

    protconn_result_yrs <- Makurhini::MK_ProtConn(
      nodes = protected_areas_filt_yr,
      region = study_area,
      area_unit = "m2",
      distance = list(type = input$distance_matrix_type),
      probability = 0.5,
      transboundary = 0,
      distance_thresholds = c(input$distance_threshold)
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
        dplyr::filter(`ProtConn indicator` %in% c("Prot", "Unprotected", "ProtConn", "ProtUnconn")) %>%
        dplyr::select(Percentage, `ProtConn indicator`)
      df$Distance <- as.numeric(gsub("^d", "", names(protconn_result_yrs)[j]))
      protconn_result_list[[j]] <- df
    }

    protconn_result_combined <- do.call(rbind, protconn_result_list)
    protconn_result_combined$Year <- yr
  }
  print(protconn_result_combined)
  protconn_ts_result[[i]] <- protconn_result_combined
  gc()
}

# Final time series dataframe
protconn_result_yrs <- do.call(rbind, protconn_ts_result)
print("Printing result years")
print(protconn_result_yrs)
print(class(protconn_result_yrs))

result_yrs <- tidyr::pivot_wider(
  data = protconn_result_yrs,
  id_cols = c("Distance", "Year"),
  names_from = "ProtConn indicator",
  values_from = "Percentage",
  id_expand = TRUE
)
print(result_yrs)

result_yrs_path <- file.path(outputFolder, "result_yrs.csv") # save protconn result
write.csv(result_yrs, result_yrs_path)
biab_output("result_yrs", result_yrs_path)

xint <- (input$start_year) + round(((input$years - input$start_year) / 2))

protconn_result_yrs <- protconn_result_yrs %>% filter(!`ProtConn indicator` == "Unprotected") # filter out unprotected for plotting

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
    annotate("text", x = xint, y = 31, label = "Kunming-Montreal target") +
    facet_wrap(~Distance) +
    geom_line() +
    theme_classic() +
    theme(strip.text.y = element_blank())

  file_path <- file.path(outputFolder, paste0("result_plot_yrs_", input$distance_threshold[i], "m.png"))
  plot_paths <- cbind(plot_paths, file_path) # put file paths in list
  ggsave(file_path, result_yrs_plot)
}

biab_output("result_yrs_plot", plot_paths)
