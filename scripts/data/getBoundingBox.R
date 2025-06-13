# Script to get the bounding box from a country or region

library("rjson")
library("sf")

input <- biab_inputs()

study_area <- input$study_area_file

# if input is a geojson, make sure it is in EPSG:4326
study_area <- sf::st_read(study_area) 

if(nrow(study_area)==0){
  biab_error_stop("Can't find polygon of study area.")
}  # stop if object is empty

# make sure data is in the correct crs
study_area <- st_transform(study_area, input$crs) # transform into input crs

# extract bounding box and create output
bbox <- sf::st_bbox(study_area)
bbox <- unname(bbox)
biab_output("bbox", bbox)
