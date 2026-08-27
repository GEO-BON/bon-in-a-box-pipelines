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

input <- fromJSON(file=file.path(outputFolder, "input.json"))

cropland=c(10, 11, 12, 20)
forest=c(50, 60, 61, 62, 70, 71, 72, 80, 81, 82, 90, 160, 170)
grassland= c(130)
shrubland= c(120, 121, 122)

lc_classes= input$lc_classes

lc_casses_nonmixed= lc_classes[!lc_classes %in% c(30, 40, 100, 110)]

## load population polygons and habitat cover map
input <- fromJSON(file=file.path(outputFolder, "input.json"))

pop_poly <-st_read(input$population_polygons)

habitat_p = input$habitat_map
print(lc_classes)
POP_HABITAT_AREA=c()
for (name in pop_poly$pop) {
  print(name)
  ## get habitat map
  habitat = rast(paste0(habitat_p,name,'.tif'))
  cell_areas <- cellSize(habitat, unit = "m")   # or unit = "km"
  ## Extract habitat cover %
  total=sapply(habitat, function(x) {global(cellSize(x, unit = "km") * (x%in% lc_classes), "sum", na.rm = TRUE)[1,1]})
  crop=sapply(habitat, function(x) {global(cellSize(x, unit = "km") * (x == 30), "sum", na.rm = TRUE)[1,1]})
  natural=sapply(habitat, function(x) {global(cellSize(x, unit = "km") * (x == 40), "sum", na.rm = TRUE)[1,1]})
  tree=sapply(habitat, function(x) {global(cellSize(x, unit = "km") * (x == 100), "sum", na.rm = TRUE)[1,1]})
  herbaceous=sapply(habitat, function(x) {global(cellSize(x, unit = "km") * (x == 110), "sum", na.rm = TRUE)[1,1]})
  if(any(lc_classes%in%cropland)){
    total=total+crop*0.66+natural*0.33
    print("cropland added")
  }
  if(any(lc_classes%in%forest) | any(lc_classes%in%shrubland)){
    total=total+tree*0.66+herbaceous*0.33
    print("forest added")
  }
  if (any(lc_classes%in%grassland)){
    total=total+tree*0.33+herbaceous*0.66
    print("grass added")
  }
  if (any(lc_classes%in%grassland) | any(lc_classes%in%forest) | any(lc_classes%in%shrubland)){
    total=total+natural*0.66+crop*0.33
    print("gras and forest added")
  }

  names(total) = names(habitat)
  
  ## add to container
  POP_HABITAT_AREA = rbind(POP_HABITAT_AREA, c('name'=name, total))

}


## Write output
path <- file.path(outputFolder, "pop_habitat_area.tsv")

write.table(POP_HABITAT_AREA, path,
            append = F, row.names = F, col.names = T, sep = "\t", quote=F)

output <- list("pop_area" = path)
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))