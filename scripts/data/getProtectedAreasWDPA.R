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
study_area_polygon<- sf::st_read(study_area)  # load study area as sf object

if(nrow(study_area_polygon)==0){
  stop("Study area polygon does not exist. Check spelling of country and state names.")
}  # stop if object is empty
print("Study area downloaded")
print(st_crs(study_area_polygon))
# Convert the input distance into degrees to create buffer for pulling protected areas
## Get centroid of the study area
if(input$transboundary_distance>0){
distance <- m_to_deg(distance_meters=input$transboundary_distance, study_area=study_area_polygon) 
 } else {distance <- 0}
print(paste("distance is", distance, "degrees"))

# Load protected area from WDPA
if(input$pa_input_type == "WDPA"){
    if(is.null(input$studyarea_state)){ # if there is only a country input (no state) # nolint
      input$studyarea_country <- gsub(" ", "+", input$studyarea_country) # Change spaces to + signs to work in the URL
      protected_area<- paste0("https://geoio.biodiversite-quebec.ca/wdpa_country_geojson/?country_name=", input$studyarea_country,"&distance=", distance) # protected areas url
      protected_area_polygon<- sf::st_read(protected_area) %>% st_transform(st_crs(study_area_polygon)) # load protected areas as sf object
    } else { # if a state is defined
      input$studyarea_country <- gsub(" ", "+", input$studyarea_country)
      input$studyarea_state <- gsub(" ", "+", input$studyarea_state)
      protected_area<- paste0("https://geoio.biodiversite-quebec.ca/wdpa_state_geojson/?country_name=", input$studyarea_country, "&state_name=", input$studyarea_state,"&distance=", distance)
      protected_area_polygon<- sf::st_read(protected_area) %>% st_transform(st_crs(study_area_polygon)) # load protected areas as sf object
    } 
} else if(input$pa_input_type == "Both") {
  # load wdpa
    if(is.null(input$studyarea_state)){ # if there is only a country input (no state) # nolint
      input$studyarea_country <- gsub(" ", "+", input$studyarea_country) # Change spaces to + signs to work in the URL
      protected_area<- paste0("https://geoio.biodiversite-quebec.ca/wdpa_country_geojson/?country_name=", input$studyarea_country,"&distance=", distance) # protected areas url
      protected_area_polygon_wdpa <- sf::st_read(protected_area) %>% st_transform(st_crs(study_area_polygon)) # load protected areas as sf object
    } else { # if a state is defined
      input$studyarea_country <- gsub(" ", "+", input$studyarea_country)
      input$studyarea_state <- gsub(" ", "+", input$studyarea_state)
      protected_area<- paste0("https://geoio.biodiversite-quebec.ca/wdpa_state_geojson/?country_name=", input$studyarea_country, "&state_name=", input$studyarea_state,"&distance=", distance)
      protected_area_polygon_wdpa <- sf::st_read(protected_area) %>% st_transform(st_crs(study_area_polygon)) # load protected areas as sf object
    }
    # load file
    protected_area_polygon_file <- sf::st_read(input$protectedarea_file) %>% st_transform(st_crs(study_area_polygon))
    # combine wdpa and file
    protected_area_polygon <- rbind(protected_area_polygon_wdpa, protected_area_polygon_file)
} else {
    protected_area_polygon <- sf::st_read(input$protectedarea_file) %>% st_transform(st_crs(study_area_polygon))
}           

if(nrow(protected_area_polygon)==0){
  stop("Protected area polygon does not exist. Check spelling of country and state names. Check if region contains protected areas")
}  # stop if object is empty

print("Protected area downloaded")
print(protected_area_polygon)


# Save study area and protected area data
study_area_polygon_path<- file.path(outputFolder, "study_area_polygon.geojson") # Define the file path for the protected area polygon output
sf::st_write(study_area_polygon, study_area_polygon_path, delete_dsn = T)

protected_area_polygon_path<- file.path(outputFolder, "protected_area_polygon.geojson") # Define the file path for the protected area polygon output
sf::st_write(protected_area_polygon, protected_area_polygon_path, delete_dsn = T)


## Outputing result to JSON
output <- list(
    # Add your outputs here "key" = "value"
    # The output keys correspond to those described in the yml file.
    study_area_polygon=study_area_polygon_path,
    protected_area_polygon=protected_area_polygon_path
    #"error" = "Some error", # halt the pipeline
    #"warning" = "Some warning", # display a warning without halting the pipeline
) 

}, error = function(e) { list(error= conditionMessage(e)) })
               
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))