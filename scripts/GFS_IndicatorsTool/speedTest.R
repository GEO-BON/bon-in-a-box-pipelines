T0=Sys.time()
library(sf)
library("rjson")


### create a set of random coordinates
set.seed(1)
points = data.frame('LON' = runif(100, -180, +180) , 'LAT' = runif(100, -90, +90))


###Define the coordinates of the center points (longitude, latitude)
points_sf <- st_as_sf(points, coords = c("LON","LAT"), crs = 4326)

# Create circular buffers around each point
circles_sf <- st_buffer(points_sf, dist = 10000)


T1=Sys.time()

print(T1-T0)


output=list('test'='empty')

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))
