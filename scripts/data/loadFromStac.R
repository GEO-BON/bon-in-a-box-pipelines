## Load required packages

library("rjson")
library("dplyr")
library("gdalcubes")
library("sf")
library("lubridate")
library("stars")
library("terra")
# sf_use_s2(FALSE)
print(outputFolder)
# source(paste(Sys.getenv("SCRIPT_LOCATION"), "/data/loadFromStacFun.R", sep = "/"))

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

if (xmin > xmax) {
  biab_error_stop("left and right seem reversed")
}
if (ymin > ymax) {
  biab_error_stop("bottom and top seem reversed")
}


# Convert date so it is in the correct format
if (!is.null(input$t0) | !is.null(input$t1)) {
  if (is.null(input$t0) | is.null(input$t1)){
    biab_error_stop("Please provide both start and end date to filter by dates")
  }

  if(is.null(input$temporal_res)){
    biab_error_stop("Please provide a temporal resolution to filter by date.")
  }
  t0 <- format(as_datetime(input$t0), "%Y-%m-%dT%H:%M:%SZ")
  t1 <- format(as_datetime(input$t1), "%Y-%m-%dT%H:%M:%SZ")
  datetime = paste0(t0, "/", t1)
}

if ("resampling" %in% names(input)) {
  resampling <- input$resampling
} else {
  resampling <- "near"
  print("No resampling method selected, defaulting to near.")
}

if ("aggregation" %in% names(input)) {
  aggregation <- input$aggregation
} else {
  aggregation <- "first"
  print("No aggregation method selected, defaulting to first.")
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
print("url output")
print(RCurl::url.exists(input$stac_url))
#if (RCurl::url.exists(input$stac_url)==FALSE){
# biab_error_stop("Could not find the URL for the STAC catalog.")
#}
s <- rstac::stac(input$stac_url)

# initialize list for items


for (coll_it in collections_items) { # Loop through input array
  print(coll_it)
  ## Case 1: Collections and IDs provided
  if (grepl("\\|", coll_it)) {
    ci <- strsplit(coll_it, split = "|", fixed = TRUE)[[1]]

    ### STAC query
    tryCatch(
      {
        it_obj <- s |>
          rstac::collections(ci[1]) |>
          rstac::items(ci[2]) |>
          rstac::get_request()
      },
      error = function(cond) {
        message("ITEM NOT FOUND. Please check STAC url or collection and item names.")
        message(cond)
        # Choose a return value in case of error
        print(exiting)
      },
      finally = {
        message("Exiting.")
      }
    )

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
      study_area <- vect(input$study_area, crs = input$crs)
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
    raster_paths <- c(raster_paths, path)

    #### Case 2: Pull all items in a collection ####
  } else { # if there are not collection items, pull entire collection
    tryCatch(
      {
        it_obj <- s |>
          rstac::collections(coll_it) |>
          rstac::items() |>
          rstac::get_request() |>
          rstac::items_fetch()
      },
      error = function(cond) {
        message("ITEM NOT FOUND. Please check STAC url or collection and item names.")
        message(cond)
        # Choose a return value in case of error
        print(exiting)
      },
      finally = {
        message("Exiting.")
      }
    )
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

    st <- gdalcubes::stac_image_collection(feats, asset_names = item_ids) # make stac image collection
    if (is.null(input$t1) & is.null(input$t0)) { # pull whole collection
      # Extract unique datetime
      dates <- vapply(it_obj$features, function(x) x$properties$`datetime`, character(1))
      print(dates)
      # Make a cube
      v <- gdalcubes::cube_view(
        srs = input$crs,
        extent = list(
          left = xmin,
          right = xmax,
          top = ymax,
          bottom = ymin,
          t0 = min(dates), # will only pull layers from that date
          t1 = max(dates),
          dx = input$spatial_res,
          dy = input$spatial_res,
          dt = "P1D",
          aggregation = input$aggregation,
          resampling = input$resampling
        )
      )
    } else { 
      dates <- vapply(it_obj$features, function(x) x$properties$`datetime`, character(1))
      if (min(dates) == max(dates)) {
        print("Ignoring date")
        v <- gdalcubes::cube_view(
          srs = input$crs,
          extent = list(
            left = xmin,
            right = xmax,
            top = ymax,
            bottom = ymin,
            t0 = min(dates), # will only pull layers from that date
            t1 = max(dates)
          ),
          dx = input$spatial_res,
          dy = input$spatial_res,
          dt = "P1D",
          aggregation = input$aggregation,
          resampling = input$resampling
        )
      } else {
        print("filtering cube by date")
        v <- gdalcubes::cube_view(
          srs = input$crs,
          extent = list(
            left = xmin,
            right = xmax,
            top = ymax,
            bottom = ymin,
            t0 = t0,
            t1 = t1
          ),
          dx = input$spatial_res,
          dy = input$spatial_res,
          dt = input$temporal_res,
          aggregation = input$aggregation,
          resampling = input$resampling
        )
      }
    }
    print(v)
    # Make raster cube
    raster_layers <- gdalcubes::raster_cube(st, v)
    name <- names(raster_layers)
    ll<-list()
    for (n in names(raster_layers)){
      ll[[n]]='data'
    }
  raster_layers <- do.call(rename_bands, c(list(raster_layers), ll)) 
    print(names(raster_layers))
    

    if (!is.null(input$study_area)) {
      poly <- st_read(input$study_area)
      raster_layers <- mask(raster_layers, poly)
    }
# temporal dimension

    out <- gdalcubes::write_tif(raster_layers,
      dir = file.path(outputFolder), prefix = paste0(coll_it, "_"),
      creation_options = list("COMPRESS" = "DEFLATE"), COG = TRUE, write_json_descr = TRUE
    )
    print("here")
    # add list of raster paths

    path <- list.files(
      path = outputFolder,
      pattern = "\\.tif$",
      full.names = TRUE
    )
    
    print(path)
    raster_paths <- c(raster_paths, path)
  }
}


biab_output("rasters", raster_paths)