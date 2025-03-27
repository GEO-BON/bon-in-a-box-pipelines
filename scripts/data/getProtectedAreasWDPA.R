# Script location can be used to access other scripts source
Sys.getenv("SCRIPT_LOCATION")

## Install required packages
#packagesPrev<- installed.packages()[,"Package"] # Check and get a list of installed packages in this machine and R version
packagesList<- list("sf", "rjson", "dplyr") # Define the list of required packages to run the script
#lapply(packagesList, function(x) {   if ( ! x %in% packagesPrev ) { install.packages(x, force=T)}    }) # Check and install required packages that are not previously installed


lapply(packagesList, library, character.only = TRUE)
## Receiving arguments from input.json.
## outputFolder is already defined by server
input <- biab_inputs()

# Load functions
## Load functions
source(paste(Sys.getenv("SCRIPT_LOCATION"), "data/metersToDegreesFun.R", sep = "/"))

# Read in study area polygon
# Read in polygon of study area
study_area <- input$study_area_polygon

# if input is a geojson, make sure it is in EPSG:4326, otherwise if it is a geopackage, just read in the file 
  study_area <- sf::st_read(study_area) 


if(nrow(study_area)==0){
  stop("Study area polygon does not exist. Check spelling of country and state names.")
}  # stop if object is empty
print("Study area downloaded")


# Convert the input distance into degrees to create buffer for pulling protected areas
## Get centroid of the study area
if(input$transboundary_distance>0){
distance <- m_to_deg(distance_meters=input$transboundary_distance, study_area=study_area) 
 } else {distance <- 0}
print(paste("distance is", distance, "degrees"))

# Load protected area from WDPA if the option is WDPA or both
if(input$pa_input_type == "WDPA" | input$pa_input_type =="Both"){
  # Load API URL
    if(is.null(input$region)){ # if there is only a country input (no state) # nolint
      input$country <- gsub(" ", "+", input$country) # Change spaces to + signs to work in the URL
      protected_areas_wdpa <- paste0("https://geoio.biodiversite-quebec.ca/wdpa_country_geojson/?country_name=", input$country,"&distance=", distance) # protected areas url
    } else { # if a state is defined
      input$country <- gsub(" ", "+", input$country)
      input$region <- gsub(" ", "+", input$region)
      protected_areas_wdpa <- paste0("https://geoio.biodiversite-quebec.ca/wdpa_state_geojson/?country_name=", input$country, "&state_name=", input$region,"&distance=", distance)
    } 
  # read in WDPA data and reproject
  protected_areas_wdpa <- sf::st_read(protected_areas_wdpa) %>% st_set_crs(4326) %>% st_transform(input$crs)
}


# if user selects user input or both, load user data
if(input$pa_input_type == "User input" | input$pa_input_type =="Both") {

  print("Loading user-defined protected areas")
  protected_areas_user <- sf::st_read(input$protected_area_file) %>% st_transform(input$crs)
  print(str(protected_areas_user))

if(!input$date_column %in% colnames(protected_areas_user)){
  biab_error_stop("The column name for the date of establishment of the protected area was not correct.")
}
# make sure date is in right format and extract year
  protected_areas_user <- protected_areas_user %>% rename(STATUS_YR = input$date_column_name)
  # extract year
  protected_areas_user$STATUS_YR <- lubridate::parse_date_time(protected_areas_user$STATUS_YR, orders=c("ymd", "mdy", "dmy", "y"))
  protected_areas_user$STATUS_YR <- lubridate::year(protected_areas_user$STATUS_YR)

if(is.null(protected_areas_user$STATUS_YR)) {
  stop("Date column is not in one of the supported formats. Supported formats are year, year-month-day, month-day-year, day-month-year (or year/month/date, month/day/year, or day/month/year)")
}
}

# if user selects both, combine the data
if(input$pa_input_type == "Both"){
  # combine if both
  protected_areas_user <- rename(protected_areas_user, geometry=geom)
  protected_areas <- dplyr::bind_rows(protected_areas_wdpa[,c("STATUS_YR", "geometry")], protected_areas_user[,c("STATUS_YR", "geometry")])
} else if (input$pa_input_type == "User input") {
  protected_areas <- protected_areas_user
} else {
  protected_areas <- protected_areas_wdpa
}

print(str(protected_areas))

if(!st_crs(study_area)==st_crs(protected_areas)){
biab_error_stop("Coordinate reference systems of protected area and study area do not match")
}


if(nrow(protected_areas)==0){
  biab_error_stop("Protected area polygons not found. Check spelling of country and state names. Check if region contains protected areas")
}  # stop if object is empty

print("Protected area downloaded")
print(protected_areas)


# Save study area and protected area data
study_area_path<- file.path(outputFolder, "study_area.gpkg") # Define the file path for the protected area polygon output
sf::st_write(study_area, study_area_path, delete_dsn = T)
biab_output("study_area", study_area_path)

protected_areas_path<- file.path(outputFolder, "protected_areas.gpkg") # Define the file path for the protected area polygon output
sf::st_write(protected_areas, protected_areas_path, delete_dsn = T)
biab_output("protected_areas", protected_areas_path)


# output number protected areas
number_pas <- nrow(protected_areas)
biab_output("number_pas", number_pas)
print("done")