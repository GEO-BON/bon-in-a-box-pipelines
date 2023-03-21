

## Install required packages
packages <- c("terra", "rjson", "raster", "stars", "dplyr", "CoordinateCleaner", "lubridate", "rgdal", "remotes", "RCurl")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)
Sys.setenv("R_REMOTES_NO_ERRORS_FROM_WARNINGS" = "true")
library("devtools")
if (!"stacatalogue" %in% installed.packages()[,"Package"]) devtools::install_github("ReseauBiodiversiteQuebec/stac-catalogue")
if (!"gdalcubes" %in% installed.packages()[,"Package"]) devtools::install_github("appelmar/gdalcubes_R")


## Load required packages

library("terra")
library("rjson")
library("raster")
library("dplyr")
library("stacatalogue")
library("gdalcubes")



input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)


# Case 1: we create an extent from a set of observations
bbox <- sf::st_bbox(c(xmin = input$bbox[1], ymin = input$bbox[2], 
            xmax = input$bbox[3], ymax = input$bbox[4]), crs = sf::st_crs(input$proj)) 


if(length(input$collections_items) == 0) {
  stop('Please specify collections_items')
} else {
  collections_items <- input$collections_items
}

source = "cube"
cube_args = list(stac_path = "http://io.biodiversite-quebec.ca/stac/",
limit = 5000,
t0 = NULL,
t1 = NULL,
spatial.res = input$spatial_res, # in meters
temporal.res = "P1D",
aggregation = "mean",
resampling = "near")
subset_layers = input$layers
variables = input$variables
proj = input$proj
as_list = F

mask=input$mask
if(mask==''){
  mask=NULL
}
predictors=list()
for (coll_it in collections_items){
    ci<-strsplit(coll_it, split = "|", fixed=TRUE)[[1]]

    cube_args_c <- append(cube_args, list(collections=ci[1],
                                          srs.cube = proj, 
                                          bbox = bbox,
                                          variable = variables,
                                          ids=ci[2]))
    pred <- do.call(stacatalogue::load_cube, cube_args_c)

     if(!is.null(mask)) {
        pred <- gdalcubes::filter_geom(pred,  sf::st_geometry(mask))
      }
      if(names(pred)=='data'){
        pred=rename_bands(pred,data=ci[2])
      }
     print(pred)

     predictors[[ci[2]]]=pred
}
  print(names(predictors))
  nc_names <- names(predictors)
  
  if (as_list) {
    output <- nc_names
    
  } else {
    
      cube_args_nc <- append(cube_args, list(layers = nc_names, 
                                             srs.cube = proj,
                                             bbox = bbox))
      output <- do.call(stacatalogue::load_cube, cube_args_nc)
      
      if(!is.null(mask)) {
        output <- gdalcubes::filter_geom(cube,  sf::st_geometry(sf::st_as_sf(mask)), srs=proj)
      }
  }

output_predictors <- file.path(outputFolder)

for (i in 1:length(predictors)) {
  ff <- tempfile(pattern = paste0(names(predictors[i][[1]]),'_'))
  gdalcubes::write_tif(predictors[i][[1]], dir = output_predictors, prefix=basename(ff),creation_options = list("COMPRESS" = "DEFLATE"), COG=T)
}

fileslist=list.files(outputFolder, pattern="*.tif")

output <- list("rasters" = paste0(file.path(outputFolder, fileslist)))
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))