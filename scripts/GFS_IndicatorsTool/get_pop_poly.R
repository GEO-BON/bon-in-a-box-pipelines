#packages <- c("sf","rjson", "spatialEco", 'rnaturalearth','rnaturalearthdata')
#new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
#if(length(new.packages)) install.packages(new.packages)

library("rjson")
library("sf")
library("spatialEco")
library("rnaturalearth")

output<- tryCatch({
input <- fromJSON(file=file.path(outputFolder, "input.json"))

# load points from file
obs_data = read.table(input$species_obs, header=T)

# restrict observation to countries of interest, if specified
countries = input$countries

if (length(countries)>0) {

  countries_poly = ne_states(geounit=countries)

  # Convert points data frame to an sf object
  points_sf <- st_as_sf(obs_data, coords = c("decimal_longitude", "decimal_latitude"), crs = 4326)  # EPSG:4326 is the CRS for WGS84 (lon/lat)
  
  # check which observation are within the polygons
  points_in_poly = st_within(points_sf, countries_poly)
  
  obs_data = obs_data[lengths(points_in_poly)>0,]

}


# get radius for buffer calculation
radius <- input$buffer_size  # in kilometers

###clean point
points = obs_data[,c("decimal_longitude", "decimal_latitude")]
colnames(points) = c("longitude","latitude")
print(nrow(points))

#if(nrow(points==0)){
#  stop("No occurences of chosen species in the study area")
#}

 
###Define the coordinates of the center points (longitude, latitude)
points_sf <- st_as_sf(points, coords = c("longitude","latitude"), crs = 4326)

# Create circular buffers around each point
circles_sf <- st_buffer(points_sf, dist = radius*1000)

#####
if (nrow(circles_sf)>1) {
  
  # calculate distance between point observations
  D = as.dist(st_distance(points_sf))/1000

  # use hierarchical clustering to split populations by geographical distancw
  pop_distance = input$pop_distance # maximal distnace to split populations
  circles_sf$pop = paste0('pop_',cutree(hclust(D, method = 'average'), h=pop_distance))
  

} else {
    
    circles_sf$pop = 'pop_1'
    
  }
  

# merge polygons by population identifier
sf_use_s2(F)
PopPoly = sf_dissolve(circles_sf, 'pop')


## remove overlap between features 
PopPoly=sf_dissolve(st_intersection(PopPoly),'pop')

## correct geometries --> if geometry collections--> extract only polygons 
for (i in which(st_geometry_type(PopPoly)=='GEOMETRYCOLLECTION')) {
  PopPoly = rbind(PopPoly , st_collection_extract(PopPoly[i,], type=c('POLYGON')))
}
PopPoly=PopPoly[which(st_geometry_type(PopPoly)!='GEOMETRYCOLLECTION'),]

## re-dissolve everything: 1 multipolygon per population
PopPoly=sf_dissolve(PopPoly, 'pop')



###prepare output
path <- file.path(outputFolder, "population_polygons.geojson")
st_write(PopPoly, path)

output <- list("population_polygons"=path) 
}, error = function(e) { list(error= conditionMessage(e)) })

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))
