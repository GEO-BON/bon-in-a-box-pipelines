## Load required packages

library("rjson")
library("dplyr")
library("gdalcubes")
library("sf")
library("lubridate")
library("stars")
library("terra")
#sf_use_s2(FALSE)

#source(paste(Sys.getenv("SCRIPT_LOCATION"), "/data/loadFromStacFun.R", sep = "/"))

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

xmin <- input$bbox[1]
ymin <- input$bbox[2]
xmax <- input$bbox[3]
ymax <- input$bbox[4]

weight_matrix <- NULL

# if (!inherits(bbox, "bbox")) {
#       stop("The bbox is not a bbox object.")
#     }
    if (xmin > xmax) {
      stop("left and right seem reversed")
    }
    if (ymin > ymax) {
      stop("bottom and top seem reversed")
    }


# Convert date so it is in the correct format
  if (!is.null(input$t0) && !is.null(input$t1)) {
    t0 <- format(as_datetime(t0), "%Y-%m-%dT%H:%M:%SZ")
    t1 <- format(as_datetime(t1), "%Y-%m-%dT%H:%M:%SZ")
    datetime <- if (t0 == t1) {
      t0
    } else {
      paste(t0, t1, sep = "/")
    }
  }

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

raster_paths <- c()

# Connect to STAC
RCurl::url.exists(input$stac_url)
s <- rstac::stac(input$stac_url)

# initialize list for items

# tryCatch(
for (coll_it in collections_items) {
  print(coll_it)
  ## Case 1: Collections and IDs provided
  if (grepl("\\|", coll_it)) { 
    ci <- strsplit(coll_it, split = "|", fixed = TRUE)[[1]]

  ### STAC query
  it_obj <- s |>
          rstac::collections(ci[1]) |>
          rstac::items(ci[2]) |>
          rstac::get_request() 

## Extract download link
urls <- vapply(it_obj$assets, function(asset) asset$href, character(1))

# Connect with terra
r <- rast(paste0("/vsicurl/", urls[1]))
print(r)

# Make empty raster with desired resolution and extent
empty_raster <- rast(xmin = input$bbox[1], xmax = input$bbox[3], ymin = input$bbox[2], ymax = input$bbox[4], resolution = as.numeric(input$spatial_res), crs = input$crs)
print(empty_raster)

# Resample
resampled <- project(r, empty_raster) 

# Crop if there is a study area
if (!is.null(input$study_area)) {
 study_area <- vect(input$study_area, crs=input$crs)
 cropped <- crop(r, study_area)
 }

# Change band names if they are all called data
if (names(resampled) == "data") {
    names(resampled) <- ci[2]
  }


# Name file path
path <- file.path(outputFolder, paste0(names(resampled), ".tif"))
print(path)

file <- writeRaster(resampled, path)

#### Case 2: Pull all items in a collection ####
  } else if (is.null(input$t1) & is.null(input$t0)) { # if there are not collection items, pull entire collection

    it_obj <- s |>
        rstac::collections(coll_it) |>
        rstac::items() |>
        rstac::get_request() |>
        rstac::items_fetch()

    # Use GDALCubes in case the layers are tiled 


    feats <- it_obj$features
    # get item IDs
    item_ids <- vapply(it_obj$features, function(x) x$id, character(1))
    print(item_ids[1])

    # Extract spatial res if not provided
    if (is.null(input$spatial_res)) { # Obtain spatial resolution from metadata
      spatial.res <-
        it_obj$assets[[name1]]$`raster:bands`[[1]]$spatial_resolution
    } else {
      spatial.res <- input$spatial_res
      }

    # Extract crs if not provided
    if (is.null(input$crs)) { # Obtain CRS from metadata
      if ("proj:epsg" %in% names(it_obj$properties)) {
        srs.cube <- paste0("EPSG:", it_obj$properties$`proj:epsg`)
      } else if (`proj:wkt2` %in% names(it_obj$properties)) {
        srs.cube <- it_obj$properties$`proj:wkt2`
      }
    } else {
      srs.cube <- input$crs
    }

    # Extract unique datetime
    dates <- vapply(it_obj$features, function(x) x$properties$`datetime`, character(1))
dates <- unique(dates)
    # Iterate through dates so that if it needs to be tiled it will 
#    for (date in dates){
#print(dates[date])
# Make a stac image collection
st <- gdalcubes::stac_image_collection(feats, asset_names = item_ids) # pull all items in a collection?

# Make a cube
v <- gdalcubes::cube_view(
      srs = input$crs,
      extent = list(
        left = xmin,
        right = xmax,
        top = ymax,
        bottom = ymin,
        t0=min(dates[date]), # will only pull layers from that date
        t1=max(dates[date])
      ),
      dx = input$spatial_res,
      dy = input$spatial_res,
      dt = "P1D",
      aggregation = input$aggregation,
      resampling = input$resampling
    ) 

print(v)
# Make raster cube

cube <- gdalcubes::raster_cube(st, v)

if (!is.null(input$study_area)){
  poly <- st_read(input$study_area)
  cube <- mask(cube, poly)
}
  #  }





#### Case 3: Pull timeseries by t0 and t1 ####
    } else { 
    it_obj <-
          s |>
          rstac::stac_search(collections,
            bbox = c(xmin, ymin, xmax, ymax),
            datetime = datetime
          ) |>
        #  rstac::get_request() |>
          rstac::items_fetch()
  }
  raster_paths <- c(raster_paths, path)
}

print("raster paths")
print(raster_paths)
#       error = function(cond) {
#         message("ITEM NOT FOUND. Please check STAC url or collection and item names.")
#         message(cond)
#         # Choose a return value in case of error
#         print(exiting)
#       },
#       finally = {
#         message("Exiting.")
#       }
#     )




#print(item_query)


  # print(cube_args_c)
  # pred <- do.call(load_cube, cube_args_c) # call load_cube function from loadFromStacFun

  # if (!is.null(input$study_area)) {
  #   study_area <- st_read(input$study_area) # load study area
  #   pred <- gdalcubes::filter_geom(pred, sf::st_geometry(study_area)) # crop by study area
  # }



  # nc_names <- cbind(nc_names, names(pred))
  # if (names(pred) == "data") {
  #   pred <- rename_bands(pred, data = ci[2])
  # }
  # print(pred)

  # raster_layers[[ci[2]]] <- pred

  biab_output("rasters", raster_paths)

# output_raster_layers <- file.path(outputFolder)

# layer_paths <- c()
# for (i in 1:length(raster_layers)) {
#   ff <- tempfile(pattern = paste0(names(raster_layers[i][[1]]), "_"))
#   out <- gdalcubes::write_tif(raster_layers[i][[1]], dir = output_raster_layers, prefix = basename(ff), creation_options = list("COMPRESS" = "DEFLATE"), COG = TRUE, write_json_descr = TRUE)
#   fp <- paste0(out[1])
#   layer_paths <- cbind(layer_paths, fp)
#   if (!is.null(weight_matrix)) {
#     weight_matrix <- sub(stac_collections_items[i], fp[1], weight_matrix, fixed = TRUE)
#   }
# }

# if (is.null(weight_matrix)) { # Temporary fix
#   weight_matrix <- ""
# }

# biab_output("rasters", layer_paths)
# biab_output("weight_matrix_with_layers", weight_matrix)
