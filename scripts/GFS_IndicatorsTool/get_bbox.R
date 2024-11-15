#packages <- c("sf","rjson", 'rnaturalearth','rnaturalearthdata' )
#new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
#if(length(new.packages)) install.packages(new.packages)

library("rjson")
library("sf")
library("geosphere")
library("rnaturalearth")

input <- fromJSON(file=file.path(outputFolder, "input.json"))

print(input)
  
country<-input$countries


bbox<-bbox<-unname(st_bbox(ne_states(geounit=country), crs=st_crs(input$proj)))
output <- list("bbox"=bbox)
  

p <- rbind(c(bbox[1],bbox[2]), c(bbox[1],bbox[4]), c(bbox[3], bbox[4]), c(bbox[3],bbox[2]))
if (areaPolygon(p)/1000000>1000000){warning("\n****************************\n",
                                            "*** WARNING: AREA TO BIG ***\n",
                                            "****************************\n",
                                            "Warning Message:Area to big, computation will take excessively long.\n\n"
                                            )}

print(output)

### return output
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))