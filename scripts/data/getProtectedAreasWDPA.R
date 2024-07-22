# Script location can be used to access other scripts source
Sys.getenv("SCRIPT_LOCATION")

## Install required packages
packagesPrev<- installed.packages()[,"Package"] # Check and get a list of installed packages in this machine and R version
packagesNeed<- list("sf", "fasterize", "this.path", "rjson", "dplyr", "terra") # Define the list of required packages to run the script
lapply(packagesNeed, function(x) {   if ( ! x %in% packagesPrev ) { install.packages(x, force=T)}    }) # Check and install required packages that are not previously installed

packagesList<-list("sf", "terra", "dplyr", "rjson")
lapply(packagesList, library, character.only = TRUE)
## Receiving arguments from input.json.
## outputFolder is already defined by server
input <- rjson::fromJSON(file=file.path(outputFolder, "input.json"))

## Parameter validation
#<YOUR VALIDATION HERE> #### add parameter validation

## Script body

# Define study area
# If a state is not defined, will pull data for the whole country
if (is.null(input$studyarea_state)){ # if there is only a country input (no state)
  input$studyarea_country <- gsub(" ", "+", input$studyarea_country) # Change spaces to + signs to work in the URL
  study_area<- paste0("https://geoio.biodiversite-quebec.ca/country_geojson/?country_name=", input$studyarea_country) # study area url
  protected_area<- paste0("https://geoio.biodiversite-quebec.ca/wdpa_country_geojson/?country_name=", input$studyarea_country) # protected areas url
} else { # if a state is defined
  input$studyarea_country <- gsub(" ", "+", input$studyarea_country)
  input$studyarea_state <- gsub(" ", "+", input$studyarea_state)
  study_area<- paste0("https://geoio.biodiversite-quebec.ca/state_geojson/?country_name=", input$studyarea_country, "&state_name=", input$studyarea_state)
  protected_area<- paste0("https://geoio.biodiversite-quebec.ca/wdpa_state_geojson/?country_name=", input$studyarea_country, "&state_name=", input$studyarea_state)
}

crs_polygon<- terra::crs("+init=epsg:4326") %>% as.character() 

# Read in study area and protected area data
study_area_polygon<- sf::st_read(study_area)  # load study area as sf object
protected_area_polygon<- sf::st_read(protected_area)  # load protected areas as sf object

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
               
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))