library(sf)
library(rjson)
library(wdpar)
library(dplyr)
library(chromote)

# Add inputs
input <- biab_inputs()

# Create chromote session
b <- ChromoteSession$new()

# Get polygon for study area

# Read in polygon of study area
if(!is.null(input$region)){
  if(is.null(input$study_area_polygon)){
    biab_error_stop("No study area polygon found. Please provide a geopackage of the study area. To pull country or region 
    shapefiles, connect this script to the 'Get country polygon' script")
  }
study_area <- input$study_area_polygon
study_area <- sf::st_read(study_area) 
}

# Make sure API key is there
if (Sys.getenv("WDPA_KEY") ==''){ # error if API key not found
  biab_error_stop("WDPA key not found. Please make sure you have an API access key in your 'runner.env' file. 
  To register for one, go to https://api.protectedplanet.net/request")
}


print("Pulling data from WDPA")
# get protected areas
# If user selects WDPA or both, load WDPA data
if(input$pa_input_type == "WDPA" | input$pa_input_type =="Both"){
    # download data
  protected_areas_wdpa <- wdpa_fetch(input$country, wait = TRUE, download_dir = rappdirs::user_data_dir("wdpar"))
  print(class(protected_areas_wdpa))

  # Crop by region if user specifies one
  # transform to crs of interest
  protected_areas_wdpa <- st_transform(protected_areas_wdpa, crs=input$crs)
  if(!is.null(input$region)){
   print("Cropping by region")
    protected_areas_wdpa <- st_intersection(protected_areas_wdpa, study_area)
    # Clean data - local level with higher previsiion
    protected_areas_wdpa <- wdpa_clean(protected_areas_wdpa, geometry_precision=10000)
  } else {
    # clean data NATIONAL LEVEL ONLY - NOT SUITABLE FOR SMALLER AREAS (excluding protected areas not yet implemented, excluding PAs with limited conservation value, 
    # replacing PAs represented as points with circular arreas that correspong to their reported extent, 
    # repairing topological issues with extents, and dissolving overlapping PAs)
    protected_areas_wdpa <- wdpa_clean(protected_areas_wdpa)
}
  # project
  protected_areas_wdpa <- protected_areas_wdpa %>% st_transform(input$crs)
  protected_areas_wdpa <- protected_areas_wdpa %>% rename(STATUS_YR = legal_status_updated)
  protected_areas_wdpa$STATUS_YR <- lubridate::parse_date_time(protected_areas_wdpa$STATUS_YR, orders=c("ymd", "mdy", "dmy", "y"))
  protected_areas_wdpa$STATUS_YR <- lubridate::year(protected_areas_wdpa$STATUS_YR)
} 


protected_areas <- protected_areas_wdpa

number_pas <- nrow(protected_areas)
biab_output("number_pas", number_pas)

print("done")

# output protected areas
protected_areas_path <- file.path(outputFolder, "protected_areas.gpkg")
sf::st_write(protected_areas, protected_areas_path, delete_dsn = T)
biab_output("protected_areas", protected_areas_path)
