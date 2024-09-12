packages <- c("raster", "rjson", "geojsonsf", "terra",'sf')
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)
if(!"rgdal"%in% installed.packages()){
  install.packages("rgdal", repos="http://R-Forge.R-project.org", type="source") 
}
if(!"gdalUtils"%in% installed.packages()){
  library(devtools)
  devtools::install_github("gearslaboratory/gdalUtils")
}
library(raster)
library(gdalUtils)
library(rjson)
library(terra)
library(sf)


## load population polygons and habitat cover map
input <- fromJSON(file=file.path(outputFolder, "input.json"))

pop_poly <-st_read(input$population_polygons)

habitat = stack(input$habitat_map)

time.points = input$time.points

names(habitat) = time.points

## Calculate Area of populations
sf_use_s2(F)
POP_AREA = st_area(pop_poly)/1000000
names(POP_AREA) = pop_poly$pop

## Extract habitat cover %
POP_HABITAT = as.matrix(terra::extract(rast(habitat), pop_poly, fun=mean))[,-1]

## Calculate population habitat area
POP_HABITAT_AREA = round(POP_HABITAT*POP_AREA,2)
colnames(POP_HABITAT_AREA) = time.points
POP_HABITAT_AREA = cbind('pop'=pop_poly$pop, POP_HABITAT_AREA)


## Write output
path <- file.path(outputFolder, "pop_habitat_area.tsv")

write.table(POP_HABITAT_AREA, path,
            append = F, row.names = F, col.names = T, sep = "\t", quote=F)

output <- list("popArea" = path) 
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))

