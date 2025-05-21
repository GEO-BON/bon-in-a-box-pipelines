library(sf)
library(rjson)
library(dplyr)
library(wdpar)

# Add inputs
input <- biab_inputs()
sf_use_s2(FALSE)
# Get polygon for study area

# Read in polygon of study area
if(is.null(input$study_area_polygon)){
  biab_error_stop("No study area polygon found. Please provide a geopackage of the study area. To pull country or region 
  shapefiles, connect this script to the 'Get country polygon' script")
  }

study_area <- input$study_area_polygon
study_area <- sf::st_read(study_area, type=3, promote_to_multi=FALSE) 
study_area <- st_transform(study_area, crs=input$crs)
study_area <- st_make_valid(study_area)

# Read in wdpa data
protected_areas <- sf::st_read(input$protected_area_file, type=3, promote_to_multi=FALSE)

# transform
protected_areas <- st_transform(protected_areas, crs=input$crs)

## Clean data
print("cleaning data")

print("Including areas based on status")
protected_areas <- protected_areas %>%
  filter(sapply(legal_status, function(x) any(grepl(paste(input$status_type, collapse = "|"), x, ignore.case = TRUE))))


if (isTRUE(input$exclude_unesco)){
print("Removing UNESCO biosphere reserves")
  protected_areas <- protected_areas %>% filter(!grepl("UNESCO-MAB Biosphere Reserve", designation))
}


# Fixing geometries

## Check if it is point and label as such
protected_areas$geometry_type <- st_geometry_type(protected_areas)
print(unique(protected_areas$geometry_type))

is_point <- vapply(sf::st_geometry(protected_areas), inherits, logical(1),
                      c("POINT", "MULTIPOINT"))
protected_areas$geometry_type[is_point] <- "POINT" # label points as a point

#deal with points
if(isTRUE(input$buffer_points)){
 print("removing points with no reported area")
protected_areas <- protected_areas[!(protected_areas$geometry_type == "POINT" & !is.finite(protected_areas$reported_area)), ]
print("creating buffer for points with reported area")
} else {
  print("removing points")
  protected_areas <- protected_areas[!(protected_areas$geometry_type == "POINT"),]
}

# Geometery fixes
print("Fixing invalid geometries")
protected_areas <- st_make_valid(protected_areas)
protected_areas <- st_buffer(protected_areas, 0)
## Repair geometries
protected_areas <- st_make_valid(protected_areas)


# Include marine
if(isFALSE(input$include_marine)){
  print("Removing marine protected areas")
protected_areas <- protected_areas %>% filter(marine==FALSE)
}

# Include OECMs
if(isFALSE(input$include_oecm)){
  print("Removing OECMs")
  protected_areas <- protected_areas %>% filter(is_oecm==FALSE)
}


## Crop data by study area
print("Cropping data by study area")
protected_areas_clean <- st_intersection(protected_areas, study_area)

# Combine protected areas that are within 10m of each other
print("Combining overlapping geometries")
protected_areas_clean <- st_buffer(protected_areas_clean, dist=10) # buffering polygons by 10 meters
intersections <- st_intersects(protected_areas_clean) # Identifying intersecting polygons

groups <- as.integer(components(graph = igraph::graph_from_adj_list(intersections))$membership) # Grouping intersecting polygons

protected_areas_clean <- study_area %>%
  group_by(group_id) %>%
  summarize(geom = st_union(geom), .groups = "drop") # COmbining intersecting polygons

protected_areas_clean_path <- file.path(outputFolder, "protected_areas_clean.gpkg")
sf::st_write(protected_areas_clean, protected_areas_clean_path, delete_dsn = T)
biab_output("protected_areas_clean", protected_areas_clean_path)

