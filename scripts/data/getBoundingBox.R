# Script to get the bounding box from a country or region

library("rjson")
library("sf")

input <- fromJSON(file=file.path(outputFolder, "input.json"))
  
# define study area
if (is.null(input$studyarea_file)){ # if there is no study area file input
  if (is.null(input$state)){ # if there is only a country input (no state) 
    input$country <- gsub(" ", "+", input$country) # Change spaces to + signs to work in the URL 
    study_area<- paste0("https://geoio.biodiversite-quebec.ca/country_geojson/?country_name=", input$country) # study area url 
  } else { # if a state is defined
   input$country <- gsub(" ", "+", input$country)
   input$state <- gsub(" ", "+", input$state)
    study_area<- paste0("https://geoio.biodiversite-quebec.ca/state_geojson/?country_name=", input$country, "&state_name=", input$state)
  } } else {study_area <- input$studyarea_file}

study_area_polygon<- sf::st_read(study_area)  # load study area as sf object
print(st_crs(study_area_polygon))
if(nrow(study_area_polygon)==0){
  stop("Study area polygon does not exist. Check spelling of country and state names. Check if region contains protected areas")
}  # stop if object is empty

# Save study area and protected area data
study_area_polygon_path<- file.path(outputFolder, "study_area_polygon.geojson") # Define the file path for the protected area polygon output
sf::st_write(study_area_polygon, study_area_polygon_path, delete_dsn = T)


# create bounding box
bbox <- sf::st_bbox(study_area_polygon) 
bbox <- st_transform(study_area_polygon, st_crs(4326))

bbox<-unname(st_bbox(study_area_polygon))

output <- list("bbox" = bbox, "study_area_polygon" = study_area_polygon_path)
print(output)

### return outpu
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))