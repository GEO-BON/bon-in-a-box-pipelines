packages <- c("sf","rjson", "spatialEco")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

library("rjson")
library("sf")
library("spatialEco")

input <- fromJSON(file=file.path(outputFolder, "input.json"))

#### Check type of input
POPinput = input$POPinput

print(input)

if (POPinput=='population_polygons') { # if input is geojson of pops: use it to calculate bbox
  
  # load geojson
  circles_sf = st_read(input$population_polygons)
  
} else  { # if population is NOT a geojson, use pre-calculated species observation points to calculate populations
  
  # load points from file
  obs_data = read.table(input$species_obs, header=T)

  # get radius for buffer calculation
  radius <- input$buffer_size  # in kilometers

  ###clean point
  points = obs_data[,c("decimal_longitude", "decimal_latitude")]
  colnames(points) = c("longitude","latitude")
  
  ###Define the coordinates of the center points (longitude, latitude)
  points_sf <- st_as_sf(points, coords = c("longitude","latitude"), crs = 4326)
  
  # Create circular buffers around each point
  circles_sf <- st_buffer(points_sf, dist = radius*1000)

  if (nrow(circles_sf)>1) {
  
  # calculate distance between point observations
  D = as.dist(st_distance(points_sf))/1000

  # use hierarchical clustering to split populations by geographical distancw
  pop_distance = input$pop_distance # maximal distnace to split populations
  circles_sf$pop = paste0('pop_',cutree(hclust(D, method = 'average'), h=pop_distance))
  
  } else {
    
    circles_sf$pop = 'pop_1'
    
  }
  
} 

# merge polygons by population identifier
sf_use_s2(F)
PopPoly = sf_dissolve(circles_sf, 'pop')

###prepare output
path <- file.path(outputFolder, "population_polygons.geojson")
st_write(PopPoly, path)

output <- list("population_polygons"=path) 

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))
