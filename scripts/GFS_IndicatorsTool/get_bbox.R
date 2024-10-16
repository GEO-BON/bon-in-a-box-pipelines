#packages <- c("sf","rjson", 'rnaturalearth','rnaturalearthdata' )
#new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
#if(length(new.packages)) install.packages(new.packages)

library('rnaturalearth')
library("rjson")
library("sf")

input <- fromJSON(file=file.path(outputFolder, "input.json"))

print(input)
  
country<-input$countries
  

bbox<-unname(st_bbox(ne_states(geounit=country), crs=st_crs(input$proj)))

output <- list("bbox"=bbox)
  
 

print(output)

### return outpu
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))