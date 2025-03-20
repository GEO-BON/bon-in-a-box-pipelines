library(sf)
library(rjson)
library(wdpar)
library(rnaturalearth)
library(rnaturalearthdata)
remotes::install_github("ropensci/rnaturalearthhires")
library(dplyr)

remotes::install_github("FRBCesab/worldpa")
library(worldpa)

# Add inputs
input <- biab_inputs()

sf::sf_use_s2(FALSE)
# Get polygon for study area
# Download the country or state boundary from rnaturalearth

if(!is.null(input$study_area_file)){ # if study area file is given, use that
# check if in put file is a geojson and check validity
  if (grepl("geojson", study_area, ignore.case = TRUE)){
  study_area <- sf::st_read(input$study_area_file)
  if (!st_crs(study_area)$epsg == 4326){
    biab_error_stop("Geojson files must be in lat long (EPSG:4326). Cannot be projected files. For projected files, input as a geopackage.")
  }
  st_set_crs(study_area, "ESPG:4326")
  study_area <- st_transform(study_area, input$crs)
} else {
  # if it is a geopackage, just load and reproject
  study_area <- sf::st_read(input$study_area_file) %>% st_transform(input$crs)
}
} else { # pull study area polygon from rnaturalearth
  if(is.null(input$region)){
   # pull whole country
   print("pulling country polygon")
    study_area <- ne_countries(country=input$country, type = "countries", scale = "medium")
  } else {
  print("pulling region polygon")
  study_area <- ne_states(country=input$country)
  study_area <- study_area %>% filter(name==input$region)
  }
}



if(nrow(study_area)==0){
  stop("Study area polygon does not exist. Check spelling of country and state names.")
}  # stop if object is empty

# transform to crs of interest
study_area <- st_transform(study_area, crs=input$crs)

print("Study area downloaded")
print(class(study_area))

# Make geometry valid
study_area <- st_make_valid(study_area)

# output country polygon
study_area_path <- file.path(outputFolder, "study_area.gpkg")
sf::st_write(study_area, study_area_path, delete_dsn = T)
biab_output("study_area", study_area_path)

# Pull data from wdpa
countries <- get_countries(key="WDPA_KEY")

country_code <- countries %>% filter(country_name==input$country)
print(country_code)

# get protected areas
# If user selects WDPA or both, load WDPA data
if(input$pa_input_type == "WDPA" | input$pa_input_type =="Both"){
  protected_areas <- get_wdpa(country_code$country_iso3, path=outputFolder, key="WDPA_KEY")
  print(class(protected_areas))
  # Crop by region if user specifies one
  # transform to crs of interest
  protected_areas <- st_transform(protected_areas, crs=input$crs)
  invalid_geoms <- protected_areas[!st_is_valid(protected_areas), ]      # Find invalid geometries
  print(invalid_geoms)
  protected_areas <- st_make_valid(protected_areas)
  your_sf_object <- st_buffer(protected_areas, dist = 0)
  if(!is.null(input$region)){
   print("Cropping by region")
    protected_areas <- st_intersection(protected_areas, study_area)
  }
  # project
  protected_areas <- protected_areas %>% st_transform(input$crs)
} 

# if user selects user input or both, load user data
if (input$pa_input_type == "User input" | input$pa_input_type =="Both"){
  protected_areas_user <- st_read(input$protected_area_file)
  # if it is geojson, check validity
  if (grepl("geojson", protected_areas_user, ignore.case = TRUE)){
  protected_areas_user <- sf::st_read(protected_areas_user)
  if (!st_crs(protected_areas_user)$epsg == 4326){
    biab_error_stop("Geojson files must be in lat long (EPSG:4326). Cannot be projected files. For projected files, input as a geopackage.")
  }
  st_set_crs(protected_areas_user, "ESPG:4326")
  }
  # reproject
  protected_areas_user <- protected_areas_user %>% st_transform(input$crs)
}
# if user selects user input, use only that data
if(input$pa_input_type == "User input"){
  protected_areas <- protected_areas_user
}

# if user selects both, combine the data
if(input$pa_input_type == "Both"){
  protected_areas <- rbind(protected_areas, protected_areas_user)
}

print("Protected areas downloaded")
# validte geometery
protected_areas <- st_make_valid(protected_areas)

if(nrow(protected_areas)==0){
  stop("Protected area polygon does not exist. Check spelling of country and state names. Check if region contains protected areas")
}  # stop if object is empty
print("Protected areas downloaded")

# output number protected areas
number_pas <- nrow(protected_areas)
biab_output("number_pas", number_pas)

print("done")

# output protected areas
protected_areas_path <- file.path(outputFolder, "protected_areas.gpkg")
sf::st_write(protected_areas, protected_areas_path, delete_dsn = T)
biab_output("protected_areas", protected_areas_path)
