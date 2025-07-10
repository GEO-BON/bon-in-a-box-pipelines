# Function to convert meters to degrees to pull protected areas within a buffer of the study area boundary

m_to_deg <- 
    function(distance_meters,
            study_area) {

centroid <- st_centroid(study_area)
point_degrees <- as.data.frame(st_coordinates(centroid))
centroid_meters <- st_transform(centroid, crs = 3857)


## Calculate offsets in meters
offset_x <- st_coordinates(centroid_meters)[,1] + distance_meters # offset in x direction (east)
print(paste0("x offset is", offset_x))
offset_y <- st_coordinates(centroid_meters)[,2] + distance_meters # offset in y direction (west)
print(paste0("y offset is", offset_y))
## Create new points with the offsets
new_point_meters_x <- st_sfc(st_point(c(offset_x, st_coordinates(centroid_meters)[,2])), crs = 3857)
print(paste0("new point meters are", new_point_meters_x))
new_point_meters_y <- st_sfc(st_point(c(st_coordinates(centroid_meters)[,1], offset_y)), crs = 3857)
print(paste0("new point meters are", new_point_meters_y))
## Transform the new points back to EPSG:4326
new_point_degrees_x <- st_transform(new_point_meters_x, crs = 4326)
new_point_degrees_y <- st_transform(new_point_meters_y, crs = 4326)
## Calculate the difference in degrees
longitude_diff <- st_coordinates(new_point_degrees_x)[,1] - point_degrees$X
print(longitude_diff)
latitude_diff <- st_coordinates(new_point_degrees_y)[,2] - point_degrees$Y
print(latitude_diff)
## Take the larger of the two

if(longitude_diff >= latitude_diff){
  distance <- longitude_diff
} else {distance <- latitude_diff}

return(distance)
}
