library(sf)
library(rjson)
library(dplyr)
library(sf)
# Add inputs
input <- biab_inputs()
sf_use_s2(FALSE)
# Get polygon for study area

# Read in polygon of study area
if (is.null(input$study_area_polygon)) {
  biab_error_stop("No study area polygon found. Please provide a geopackage of the study area. To pull country or region
  shapefiles, connect this script to the 'Get country polygon' script")
}

# Load and fix geometry issues in study area
study_area <- input$study_area_polygon
study_area <- sf::st_read(study_area)
study_area <- st_transform(study_area, crs = input$crs)

any_invalid <- any(!st_is_valid(study_area))

if (any_invalid) {
  message("Invalid geometries detected. Fixing...")
  study_area <- st_buffer(study_area, 0.1)
  study_area_clean <- st_make_valid(study_area)
} else {
  study_area_clean <- study_area
}

study_area_clean_path <- file.path(outputFolder, "study_area_clean.gpkg")
sf::st_write(study_area_clean, study_area_clean_path, delete_dsn = T)
biab_output("study_area_clean", study_area_clean_path)

# Read in wdpa data
protected_areas <- sf::st_read(input$protected_area_file)

# # transform
protected_areas <- st_transform(protected_areas, crs = input$crs)
print(unique(protected_areas$legal_status))
# ## Clean data
print("Cleaning data")

print("Including areas based on status")
protected_areas <- protected_areas %>%
  filter(sapply(legal_status, function(x) any(grepl(paste(input$status_type, collapse = "|"), x, ignore.case = TRUE))))


if (isFALSE(input$include_unesco)) {
  print("Removing UNESCO biosphere reserves")
  protected_areas <- protected_areas %>% filter(!grepl("UNESCO-MAB Biosphere Reserve", designation))
}


# Fixing geometries

## Check if it is point and label as such
protected_areas$geometry_type <- st_geometry_type(protected_areas)


is_point <- vapply(
  sf::st_geometry(protected_areas), inherits, logical(1),
  c("POINT", "MULTIPOINT")
)
protected_areas$geometry_type[is_point] <- "POINT" # label points as a point

# deal with points
if (isTRUE(input$buffer_points)) {
  print("Removing points with no reported area or area of 0")
  protected_areas$reported_area <- as.numeric(protected_areas$reported_area)

  protected_areas <- protected_areas %>% filter(!(geometry_type == "POINT" & (is.na(reported_area) | reported_area == 0)))

  points_data <- protected_areas[(protected_areas$geometry_type == "POINT"),]


  if(nrow(points_data) > 0){
    points_data <- points_data %>%
    mutate(buffer_radius = sqrt((as.numeric(reported_area) * 1e6) / pi))
    points_data <- st_buffer(points_data, dist = points_data$buffer_radius)
    points_data <- points_data %>% select(!buffer_radius)

      if (any(protected_areas$geometry_type == "POLYGON")) {
      protected_areas <- rbind(protected_areas[which(protected_areas$geometry_type %in% c("POLYGON", "MULTIPOLYGON")), ], points_data)
      } else {
      protected_areas <- points_data
      }
  } else {
    print("There are no protected areas represented as points")
    protected_areas <- protected_areas
    }
} else {
  print("Removing points")
  protected_areas <- protected_areas[!(protected_areas$geometry_type == "POINT"), ]
}

# Geometery fixes
print("Fixing invalid geometries")

print(nrow(protected_areas))

any_invalid <- any(!st_is_valid(protected_areas))

if (any_invalid) {
  message("Invalid geometries detected. Fixing...")
protected_areas <- st_buffer(protected_areas, 0)
protected_areas <- st_make_valid(protected_areas)
} 

print("Removing slivers (protected areas less than 1 square meters)")
sliver_threshold <- units::set_units(1, "m^2")
protected_areas <- protected_areas[(sf::st_area(protected_areas)) > sliver_threshold, ]
print(nrow(protected_areas))

# Include marine
if (isFALSE(input$include_marine)) {
  print("Removing marine protected areas")
  protected_areas <- protected_areas %>% filter(marine == FALSE)
}
print(nrow(protected_areas))
# Include OECMs
if (isFALSE(input$include_oecm)) {
  print("Removing OECMs")
  protected_areas <- protected_areas %>% filter(is_oecm == FALSE)
}
print(nrow(protected_areas))

if(nrow(protected_areas_clean)==0){
  biab_error_stop("There are no protected areas.")
}

protected_areas_clean_path <- file.path(outputFolder, "protected_areas_clean.gpkg")
sf::st_write(protected_areas_clean, protected_areas_clean_path, delete_dsn = T)
biab_output("protected_areas_clean", protected_areas_clean_path)


