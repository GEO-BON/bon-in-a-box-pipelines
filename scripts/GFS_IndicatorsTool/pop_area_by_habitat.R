#packages <- c("raster", "rjson", "geojsonsf", "terra",'sf')
#new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
#if(length(new.packages)) install.packages(new.packages)
#if(!"rgdal"%in% installed.packages()){
#  install.packages("rgdal", repos="http://R-Forge.R-project.org", type="source")
#}
#if(!"gdalUtils"%in% installed.packages()){
#  library(devtools)
#  devtools::install_github("gearslaboratory/gdalUtils")
#}
library(gdalUtils)
library(rjson)
library(terra)
library(sf)


## load population polygons and habitat cover map
input <- fromJSON(file=file.path(outputFolder, "input.json"))

pop_poly <-st_read(input$population_polygons)

habitat_p = input$habitat_map

## Calculate Area of populations
sf_use_s2(F)
POP_AREA = st_area(pop_poly)/1000000
names(POP_AREA) = pop_poly$name

### Extract habitat size over time for every pop
POP_HABITAT_AREA = c() # initialize container

for (name in pop_poly$name) {
  print(name)
  ## get habitat map
  habitat = rast(paste0(habitat_p,name,'.tif'))

  ## Extract habitat cover %
  pop_habitat = unlist(lapply(habitat, function(x) {mean(x[], na.rm=T)}))

  ## Calculate population habitat area
  pop_habitat_area = round(pop_habitat*POP_AREA[name],2)
  names(pop_habitat_area) = names(habitat)
  
  ## add to container
  POP_HABITAT_AREA = rbind(POP_HABITAT_AREA, c('name'=name, pop_habitat_area))

}




## Write output
path <- file.path(outputFolder, "pop_habitat_area.tsv")

write.table(POP_HABITAT_AREA, path,
            append = F, row.names = F, col.names = T, sep = "\t", quote=F)

output <- list("pop_area" = path)
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))

