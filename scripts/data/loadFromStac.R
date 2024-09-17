

## Install required packages

## Load required packages

library("rjson")
library("dplyr")
library("gdalcubes")
library("sf")
sf_use_s2(FALSE)

source(paste(Sys.getenv("SCRIPT_LOCATION"), "/data/loadFromStacFun.R", sep = "/"))

input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)

gdalcubes_set_gdal_config("VSI_CACHE", "TRUE")
gdalcubes_set_gdal_config("GDAL_CACHEMAX","30%")
gdalcubes_set_gdal_config("VSI_CACHE_SIZE","10000000")
gdalcubes_set_gdal_config("GDAL_HTTP_MULTIPLEX","YES")
gdalcubes_set_gdal_config("GDAL_INGESTED_BYTES_AT_OPEN","32000")
gdalcubes_set_gdal_config("GDAL_DISABLE_READDIR_ON_OPEN","EMPTY_DIR")
gdalcubes_set_gdal_config("GDAL_HTTP_VERSION","2")
gdalcubes_set_gdal_config("GDAL_HTTP_MERGE_CONSECUTIVE_RANGES","YES")
gdalcubes_set_gdal_config("CHECK_WITH_INVERT_PROJ","FALSE")
gdalcubes_set_gdal_config("GDAL_NUM_THREADS", 1)

gdalcubes::gdalcubes_options(parallel = 1)

# Case 1: we create an extent from a set of observations
bbox <- sf::st_bbox(c(xmin = input$bbox[1], ymin = input$bbox[2],
            xmax = input$bbox[3], ymax = input$bbox[4]), crs = sf::st_crs(input$proj)) 
weight_matrix <- NULL
if("taxa" %in% names(input)){ #EXTRACT GBIF HEATMAPS
  collections_items <- paste0("gbif_heatmaps|", input$taxa, "-heatmap")
}else{ #EXTRACT OTHER LAYERS
  if (length(input$collections_items) == 0) {
    if (length(input$weight_matrix_with_ids) == 0) {
      stop('Please specify collections_items')
    } else {
      weight_matrix<-input$weight_matrix_with_ids
      stac_collections_items <- unlist(lapply((str_split(weight_matrix,'\n',simplify=T) |> str_split(','))[-1],function(l){l[1]}))
      stac_collections_items <- stac_collections_items[startsWith(stac_collections_items,'GBSTAC')]
      collections_items <- gsub('GBSTAC|','',stac_collections_items, fixed=TRUE)
    }
  } else {
    collections_items <- input$collections_items
  }
}
if(!("stac_url" %in% names(input))){
  input$stac_url <- "https://stac.geobon.org"
}

cube_args <- list(stac_path = input$stac_url,
  limit = 5000,
  t0 = NULL,
  t1 = NULL,
  spatial.res = input$spatial_res, # in meters
  temporal.res = "P1D",
  aggregation = "mean",
  resampling = "near")

proj <- input$proj
as_list <- FALSE

mask <- input$mask
raster_layers <- list()
nc_names <- c()
for (coll_it in collections_items){
    ci <- strsplit(coll_it, split = "|", fixed=TRUE)[[1]]

    cube_args_c <- append(cube_args, list(collections=ci[1],
                                          srs.cube = proj, 
                                          bbox = bbox,
                                          layers=NULL,
                                          variable = NULL,
                                          ids=ci[2]))
    print(cube_args_c)
    pred <- do.call(load_cube, cube_args_c)

     if(!is.null(mask)) {
        pred <- gdalcubes::filter_geom(pred, sf::st_geometry(mask))
      }
      nc_names <- cbind(nc_names,names(pred))
      if(names(pred)=='data'){
        pred <- rename_bands(pred, data=ci[2])
      }
     print(pred)

     raster_layers[[ci[2]]]=pred
}
  print(names(raster_layers))

output_raster_layers <- file.path(outputFolder)

layer_paths<-c()
for (i in 1:length(raster_layers)) {
  ff <- tempfile(pattern = paste0(names(raster_layers[i][[1]]),'_'))
  out<-gdalcubes::write_tif(raster_layers[i][[1]], dir = output_raster_layers, prefix=basename(ff),creation_options = list("COMPRESS" = "DEFLATE"), COG=TRUE, write_json_descr=TRUE)
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