## Install required packages
packages <- c("rjson","sf","readr")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

library(readr)
library(sf)  
library("rjson")


### Receiving arguments from input.json.
input <- fromJSON(file=file.path(outputFolder, "input.json"))
###Load inputs
columnnames<-c("decimal_longitude", "decimal_latitude")
bbox<-input$bbox

if(endsWith(paste("~", input$obs, sep = ""),".csv")){
  point<-read.csv(input$obs)
}
if(endsWith(paste("~", input$obs, sep = ""),".tsv")){
  point<-read_tsv(input$obs)
}
#point<-read_tsv("/Users/simonrabenmeister/Downloads/obs_data (5).tsv")
radius <- input$buffer  # in kilometers

###clean point
point<-point[colnames(point) %in% columnnames]
print(point)
colnames(point)<-c("longitude","latitude")


###Define the coordinates of the center points (longitude, latitude)
points_sf <- st_as_sf(point, coords = c("longitude","latitude"), crs = 4326)

# Create circular buffers around each point
circles_sf <- st_buffer(points_sf, dist = radius)

# Union all overlapping circles into single polygons
unioned_sf <- st_union(circles_sf, by_feature = FALSE)

## Extract only polygons from the geometry collection
unioned_sf<-st_collection_extract(unioned_sf, "POLYGON")
# Explode the unioned result into individual polygons
unioned_sf <- st_cast(unioned_sf, "POLYGON")


# Convert to sf object
unioned_sf <- st_as_sf(unioned_sf)



###prepare output
path <- file.path(outputFolder, "poly.geojson")
st_write(unioned_sf, path)

output <- list("poly"=path) 

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))

