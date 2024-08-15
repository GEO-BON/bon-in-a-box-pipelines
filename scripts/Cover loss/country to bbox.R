packages <- c("sf","rjson", 'rnaturalearth','rnaturalearthdata' )
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

library('rnaturalearth')
library("rjson")
library("sf")


input <- fromJSON(file=file.path(outputFolder, "input.json"))
country<-input$country

bbox<-unname(st_bbox(ne_countries(country=country, scale = "medium")))

output <- list("bbox"=bbox)

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))