# Script location can be used to access other scripts source
Sys.getenv("SCRIPT_LOCATION")

## Install required packages
#packagesPrev<- installed.packages()[,"Package"] # Check and get a list of installed packages in this machine and R version
packagesList<- list("sf", "rjson", "dplyr") # Define the list of required packages to run the script
#lapply(packagesList, function(x) {   if ( ! x %in% packagesPrev ) { install.packages(x, force=T)}    }) # Check and install required packages that are not previously installed


lapply(packagesList, library, character.only = TRUE)
## Receiving arguments from input.json.
## outputFolder is already defined by server
input <- rjson::fromJSON(file=file.path(outputFolder, "input.json"))

# Load functions
## Load functions
source(paste(Sys.getenv("SCRIPT_LOCATION"), "data/metersToDegreesFun.R", sep = "/"))

output<- tryCatch({
# Define study area


# If a state is not defined, will pull data for the whole country
if (is.null(input$studyarea_file)){ # if there is no study area file input
  if (is.null(input$studyarea_state)){ # if there is only a country input (no state) 
    input$studyarea_country <- gsub(" ", "+", input$studyarea_country) # Change spaces to + signs to work in the URL 
    study_area<- paste0("https://geoio.biodiversite-quebec.ca/country_geojson/?country_name=", input$studyarea_country) # study area url 
  } else { # if a state is defined
   input$studyarea_country <- gsub(" ", "+", input$studyarea_country)
   input$studyarea_state <- gsub(" ", "+", input$studyarea_state)
    study_area<- paste0("https://geoio.biodiversite-quebec.ca/state_geojson/?country_name=", input$studyarea_country, "&state_name=", input$studyarea_state)
  } } else {study_area <- input$studyarea_file}

# Read in study area polygon
# If it is a geojson, make sure it is valid and set crs to 4326
if (grepl("geojson", study_area, ignore.case = TRUE)){
  study_area <- sf::st_read(study_area)
  if (!st_crs(study_area)$epsg == 4326){
    biab_error_stop("Geojson files must be in lat long (EPSG:4326). Cannot be projected files. For projected files, input as a geopackage.")
  }
  st_set_crs(study_area, "ESPG:4326")
  study_area <- st_transform(study_area, input$crs)
} else {
  # if it is a geopackage, just load and reproject
  study_area <- sf::st_read(study_area) %>% st_transform(input$crs)
}


if(nrow(study_area)==0){
  stop("Study area polygon does not exist. Check spelling of country and state names.")
}  # stop if object is empty
print("Study area downloaded")
print(st_crs(study_area))


# Convert the input distance into degrees to create buffer for pulling protected areas
## Get centroid of the study area
if(input$transboundary_distance>0){
distance <- m_to_deg(distance_meters=input$transboundary_distance, study_area=study_area) 
 } else {distance <- 0}
print(paste("distance is", distance, "degrees"))

# Load protected area from WDPA if the option is WDPA or both
if(input$pa_input_type == "WDPA" | input$pa_input_type =="Both"){
  # Load API URL
    if(is.null(input$studyarea_state)){ # if there is only a country input (no state) # nolint
      input$studyarea_country <- gsub(" ", "+", input$studyarea_country) # Change spaces to + signs to work in the URL
      protected_areas_wdpa <- paste0("https://geoio.biodiversite-quebec.ca/wdpa_country_geojson/?country_name=", input$studyarea_country,"&distance=", distance) # protected areas url
    } else { # if a state is defined
      input$studyarea_country <- gsub(" ", "+", input$studyarea_country)
      input$studyarea_state <- gsub(" ", "+", input$studyarea_state)
      protected_areas_wdpa <- paste0("https://geoio.biodiversite-quebec.ca/wdpa_state_geojson/?country_name=", input$studyarea_country, "&state_name=", input$studyarea_state,"&distance=", distance)
    } 
  # Load data
  # Check validity if it is geojson, transform
  if (grepl("geojson", protected_areas_wdpa, ignore.case = TRUE)){
  protected_areas_wdpa <- sf::st_read(protected_areas_wdpa)
  if (!st_crs(protected_areas_wdpa)$epsg == 4326){
    biab_error_stop("Geojson files must be in lat long (EPSG:4326). Cannot be projected files. For projected files, input as a geopackage.")
  }
  st_set_crs(protected_areas_wdpa, "ESPG:4326")
  protected_areas_wdpa <- st_transform(protected_areas_wdpa, input$crs)
} else {
  # if it is a geopackage, just load and reproject
  protected_areas_wdpa <- sf::st_read(protected_areas_wdpa) %>% st_transform(input$crs)
}
} 

# if user selects user input or both, load user data
if(input$pa_input_type == "User Input" | input$pa_input_type =="Both") {
  protected_areas_user <- input$protectedarea_file

    if (grepl("geojson", protected_areas_user, ignore.case = TRUE)){
  protected_areas_user <- sf::st_read(protected_areas_user)
  if (!st_crs(protected_areas_user)$epsg == 4326){
    biab_error_stop("Geojson files must be in lat long (EPSG:4326). Cannot be projected files. For projected files, input as a geopackage.")
  }
  st_set_crs(protected_areas_user, "ESPG:4326")
  protected_areas_user <- st_transform(protected_areas_user, input$crs)
} else {
  # if it is a geopackage, just load and reproject
  protected_areas_user <- sf::st_read(protected_areas_user) %>% st_transform(input$crs)
}
    }


# if user selects both, combine the data
if(input$pa_input_type == "Both"){
  # combine if both
  protected_areas <- rbind(protected_areas_wdpa, protected_areas_user)
} else if (input$pa_input_type == "User input") {
  protected_areas <- protected_areas_user
} else {
  protected_areas <- protected_areas_wdpa
}

if(!st_crs(study_area)==st_crs(protected_areas)){
biab_error_stop("Coordinate reference systems of protected area and study area do not match")
}


if(nrow(protected_areas)==0){
  stop("Protected area polygon does not exist. Check spelling of country and state names. Check if region contains protected areas")
}  # stop if object is empty

print("Protected area downloaded")
print(protected_areas)


# Save study area and protected area data
study_area_path<- file.path(outputFolder, "study_area.gpkg") # Define the file path for the protected area polygon output
sf::st_write(study_area, study_area_path, delete_dsn = T)

protected_areas_path<- file.path(outputFolder, "protected_areas.gpkg") # Define the file path for the protected area polygon output
sf::st_write(protected_areas, protected_areas_path, delete_dsn = T)


## Outputing result to JSON
output <- list(
    # Add your outputs here "key" = "value"
    # The output keys correspond to those described in the yml file.
    study_area=study_area_path,
    protected_areas=protected_areas_path
    #"error" = "Some error", # halt the pipeline
    #"warning" = "Some warning", # display a warning without halting the pipeline
) 

}, error = function(e) { list(error= conditionMessage(e)) })
               
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))