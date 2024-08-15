

## Install required packages
#packages <- c("terra", "rjson", "raster", "stars", "dplyr", "CoordinateCleaner", "lubridate", "rgdal", "remotes", "RCurl")
#new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
#if(length(new.packages)) install.packages(new.packages)
#Sys.setenv("R_REMOTES_NO_ERRORS_FROM_WARNINGS" = "true")
#library("devtools")
#if (!"stacatalogue" %in% installed.packages()[,"Package"]) devtools::install_github("ReseauBiodiversiteQuebec/stac-catalogue")
#if (!"gdalcubes" %in% installed.packages()[,"Package"]) devtools::install_github("appelmar/gdalcubes_R")


## Load required packages

#library("terra")
library("rjson")
#library("raster")
library("dplyr")
library("gdalcubes")
library("sf")
sf_use_s2(FALSE)
#library("stringr")

source(paste(Sys.getenv("SCRIPT_LOCATION"), "/data/loadFromStacFun.R", sep = "/"))

input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)

#gdalcubes_set_gdal_config("VSI_CACHE", "TRUE")
#gdalcubes_set_gdal_config("GDAL_CACHEMAX","30%")
#gdalcubes_set_gdal_config("VSI_CACHE_SIZE","10000000")
#gdalcubes_set_gdal_config("GDAL_HTTP_MULTIPLEX","YES")
#gdalcubes_set_gdal_config("GDAL_INGESTED_BYTES_AT_OPEN","32000")
#gdalcubes_set_gdal_config("GDAL_DISABLE_READDIR_ON_OPEN","EMPTY_DIR")
#gdalcubes_set_gdal_config("GDAL_HTTP_VERSION","2")
#gdalcubes_set_gdal_config("GDAL_HTTP_MERGE_CONSECUTIVE_RANGES","YES")
gdalcubes_set_gdal_config("CHECK_WITH_INVERT_PROJ","FALSE")
gdalcubes_set_gdal_config("GDAL_NUM_THREADS", 1)

gdalcubes::gdalcubes_options(parallel = 1)

# Case 1: we create an extent from a set of observations
bbox <- sf::st_bbox(c(xmin = input$bbox[1], ymin = input$bbox[2],
            xmax = input$bbox[3], ymax = input$bbox[4]), crs = sf::st_crs(input$proj)) 
print(bbox)
print(length(input$collections_items))

if (length(input$collections_items)==0) {
  if (length(input$weight_matrix_with_ids) == 0) {
    stop('Please specify collections_items')
  } else {
    weight_matrix<-input$weight_matrix_with_ids
    stac_collections_items <- unlist(lapply((str_split(weight_matrix,'\n',simplify=T) |> str_split(','))[-1],function(l){l[1]}))
    stac_collections_items <- stac_collections_items[startsWith(stac_collections_items,'GBSTAC')]
    collections_items <- gsub('GBSTAC|','',stac_collections_items, fixed=TRUE)
  }
} else {
  weight_matrix=NULL
  collections_items <- input$collections_items
}


subset_layers = input$layers
proj = input$proj
as_list = F

mask=input$mask
predictors=list()
nc_names=c()
for (coll_it in collections_items){
    ci<-strsplit(coll_it, split = "|", fixed=TRUE)[[1]]

    pred <- load_cube(
      stac_path = input$stac_url,
      limit = 5000,
      t0 = NULL,
      t1 = NULL,
      spatial.res = input$spatial_res, # in meters
      temporal.res = "P1D",
      aggregation = "mean",
      resampling = "near",
      collections=ci[1],
      srs.cube = proj,
      bbox = bbox,
      layers=NULL,
      variable = NULL,
      ids=ci[2])

     if(!is.null(mask)) {
        pred <- gdalcubes::filter_geom(pred, sf::st_geometry(mask))
      }
      nc_names <- cbind(nc_names,names(pred))
      if(names(pred)=='data'){
        pred <- rename_bands(pred, data=ci[2])
      }
     print(pred)

     predictors[[ci[2]]]=pred
}
  print(names(predictors))

output_predictors <- file.path(outputFolder)

layer_paths<-c()
for (i in 1:length(predictors)) {
  ff <- tempfile(pattern = paste0(names(predictors[i][[1]]),'_'))
  print("Predictors")
  print(predictors[i][[1]])
  gdalcubes_options(parallel = TRUE, debug = TRUE)
  gdalcubes_options()
  out<-gdalcubes::write_tif(predictors[i][[1]], dir = output_predictors, prefix=basename(ff),creation_options = list("COMPRESS" = "DEFLATE"), COG=TRUE, overviews=TRUE)
  #out<-gdalcubes::write_tif(predictors[i][[1]], dir = output_predictors, prefix=basename(ff))
  fp <- paste0(out[1])
  layer_paths <- cbind(layer_paths,fp)
  if(!is.null(weight_matrix)) {
    weight_matrix <- sub(stac_collections_items[i],fp[1], weight_matrix, fixed=TRUE)
  }
}

 if(is.null(weight_matrix)) { #Temporary fix
  weight_matrix=''
 }

output <- list("rasters" = layer_paths,"weight_matrix_with_layers" = weight_matrix)
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))