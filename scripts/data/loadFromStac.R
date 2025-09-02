## Load required packages

library("rjson")
library("dplyr")
library("gdalcubes")
library("sf")
library("lubridate")
sf_use_s2(FALSE)

source(paste(Sys.getenv("SCRIPT_LOCATION"), "/data/loadFromStacFun.R", sep = "/"))

input <- biab_inputs()

gdalcubes_set_gdal_config("VSI_CACHE", "TRUE") # enable caching to speed up access to remote files
gdalcubes_set_gdal_config("GDAL_CACHEMAX", "30%") # set maximum cache to 30% of system RAM
gdalcubes_set_gdal_config("VSI_CACHE_SIZE", "10000000") # sets size of cache size to 10MB
gdalcubes_set_gdal_config("GDAL_HTTP_MULTIPLEX", "YES") # allows multiple requests at once
gdalcubes_set_gdal_config("GDAL_INGESTED_BYTES_AT_OPEN", "32000") # prefetch first 32 KB of a file
gdalcubes_set_gdal_config("GDAL_DISABLE_READDIR_ON_OPEN", "EMPTY_DIR") # disables directory listing when opening remote files, which avoids unnecessary costly HTTP requests.
gdalcubes_set_gdal_config("GDAL_HTTP_VERSION", "2") # force use of HTTP/2 for fetching remote data
gdalcubes_set_gdal_config("GDAL_HTTP_MERGE_CONSECUTIVE_RANGES", "YES") # if multiple consecutive byte ranges are requested, merge them into a single HTTP request
gdalcubes_set_gdal_config("CHECK_WITH_INVERT_PROJ", "FALSE") # disable checks on coordinate transformations to speed up projectsins
gdalcubes_set_gdal_config("GDAL_NUM_THREADS", 1) # restrict GDAL threads to 1

gdalcubes::gdalcubes_options(parallel = 1)

bbox <- sf::st_bbox(c(
  xmin = input$bbox[1], ymin = input$bbox[2],
  xmax = input$bbox[3], ymax = input$bbox[4]
), crs = sf::st_crs(input$crs))
weight_matrix <- NULL

if ("resampling" %in% names(input)) {
  resampling <- input$resampling
} else {
  resampling <- "near"
}

if ("aggregation" %in% names(input)) {
  aggregation <- input$aggregation
} else {
  aggregation <- "first"
}

if ("taxa" %in% names(input)) { # EXTRACT GBIF HEATMAPS
  collections_items <- paste0("gbif_heatmaps|", input$taxa, "-heatmap")
  resampling <- "sum" # Sum number of occurences when upscaling
} else { # EXTRACT OTHER LAYERS
  if (length(input$collections_items) == 0) {
    if (length(input$weight_matrix_with_ids) == 0) {
      stop("Please specify collections_items")
    } else {
      weight_matrix <- input$weight_matrix_with_ids
      stac_collections_items <- unlist(lapply((str_split(weight_matrix, "\n", simplify = T) |> str_split(","))[-1], function(l) {
        l[1]
      }))
      stac_collections_items <- stac_collections_items[startsWith(stac_collections_items, "GBSTAC")]
      collections_items <- gsub("GBSTAC|", "", stac_collections_items, fixed = TRUE)
    }
  } else {
    collections_items <- input$collections_items
  }
}

if (!("stac_url" %in% names(input))) {
  input$stac_url <- "https://stac.geobon.org"
}



cube_args <- list(
  stac_path = input$stac_url,
  limit = 5000,
  spatial.res = input$spatial_res, # in meters
  temporal.res = "P1D",
  aggregation = aggregation,
  resampling = resampling
)

crs <- input$crs
as_list <- FALSE

raster_layers <- list()
nc_names <- c()

for (coll_it in collections_items) {
  print(coll_it)
  if (grepl("\\|", coll_it)) { # if there are collection items
    ci <- strsplit(coll_it, split = "|", fixed = TRUE)[[1]]
    cube_args_c <- append(cube_args, list(
      collections = ci[1],
      srs.cube = crs,
      bbox = bbox,
      layers = NULL,
      variable = NULL,
      ids = ci[2]
    ))
  } else if (is.null(input$t1) & is.null(input$t0)) { # if there are not collection items, pull entire collection
    cube_args_c <- append(cube_args, list(
      collections = coll_it,
      srs.cube = crs,
      bbox = bbox,
      t0 = NULL,
      t1 = NULL,
      layers = NULL,
      variable = NULL,
      ids = NULL
    )) } else { # pull by datetime
    cube_args_c <- append(cube_args, list(
      collections = coll_it,
      srs.cube = crs,
      bbox = bbox,
      t0 = input$t0,
      t1 = input$t1,
      layers = NULL,
      variable = NULL,
      ids = NULL
    ))
  }

  print(cube_args_c)
  pred <- do.call(load_cube, cube_args_c) # call load_cube function from loadFromStacFun

  if (!is.null(input$study_area)) {
    study_area <- st_read(input$study_area) # load study area
    pred <- gdalcubes::filter_geom(pred, sf::st_geometry(study_area)) # crop by study area
  }
  nc_names <- cbind(nc_names, names(pred))
  if (names(pred) == "data") {
    pred <- rename_bands(pred, data = ci[2])
  }
  print(pred)

  raster_layers[[ci[2]]] <- pred
}
output_raster_layers <- file.path(outputFolder)

layer_paths <- c()
for (i in 1:length(raster_layers)) {
  ff <- tempfile(pattern = paste0(names(raster_layers[i][[1]]), "_"))
  out <- gdalcubes::write_tif(raster_layers[i][[1]], dir = output_raster_layers, prefix = basename(ff), creation_options = list("COMPRESS" = "DEFLATE"), COG = TRUE, write_json_descr = TRUE)
  fp <- paste0(out[1])
  layer_paths <- cbind(layer_paths, fp)
  if (!is.null(weight_matrix)) {
    weight_matrix <- sub(stac_collections_items[i], fp[1], weight_matrix, fixed = TRUE)
  }
}

if (is.null(weight_matrix)) { # Temporary fix
  weight_matrix <- ""
}

biab_output("rasters", layer_paths)
biab_output("weight_matrix_with_layers", weight_matrix)
