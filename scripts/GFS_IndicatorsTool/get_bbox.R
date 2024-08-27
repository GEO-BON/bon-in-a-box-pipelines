packages <- c("sf","rjson", 'rnaturalearth','rnaturalearthdata' )
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

library('rnaturalearth')
library("rjson")
library("sf")

input <- fromJSON(file=file.path(outputFolder, "input.json"))

#### Check type of input
POPinput = input$POPinput

print(input)

if (POPinput=='population_polygons') { # if input is geojson of pops: use it to calculate bbox
  
  # load geojson
  pops = st_read(input$population_polygons)
  
  # calculate bbox
  bbox = st_bbox(pops)
  
  output <- list("bbox"=bbox)
  
  
} else if (POPinput=='species_obs') { # if input are pre-selected point, calculate bbox
  
  # load points from file
  obs_data = read.table(input$species_obs, header=T)
  
  # extract bbox from coordinates
  bbox = c(min(obs_data$decimal_longitude),
           min(obs_data$decimal_latitude),
           max(obs_data$decimal_longitude),
           max(obs_data$decimal_latitude))
  
  output <- list("bbox"=bbox)
  
} else if (POPinput=='bbox') {  # if input is already a bbox: keep bbox as output
  
  output <- list("bbox"=input$bbox)
  
} else if (POPinput=='countries') { # if input is country name: use country name to calculate bbox
  
  country<-input$countries
  
  bbox<-unname(st_bbox(ne_states(geounit=country)))
  
  output <- list("bbox"=bbox)
  
} 

print(output)

### return outpu
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))