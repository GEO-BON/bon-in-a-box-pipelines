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
CRS <- paste0(input$bbox_crs$CRS$authority, ":", input$bbox_crs$CRS$code)
bounding_box <- input$bbox_crs$bbox

if (is.null(CRS) || is.null(bounding_box)) {
  biab_error_stop("Please select a country/region and CRS. When using a custom study area,
  select the country/region that contains the study area and a CRS to use.")
}

xmin <- bounding_box[1]
ymin <- bounding_box[2]
xmax <- bounding_box[3]
ymax <- bounding_box[4]

weight_matrix <- NULL

# Load study area polygon
if (!is.null(input$study_area)) {
  poly <- st_read(input$study_area)
  if (!is.null(CRS) && st_crs(poly)$epsg != CRS) {
    poly <- st_transform(poly, CRS)
  }
}

if (xmin > xmax) {
  biab_error_stop("left and right seem reversed")
}
if (ymin > ymax) {
  biab_error_stop("bottom and top seem reversed")
}

if (grepl("chelsa", input$collections_items[1], ignore.case = TRUE) && (!is.null(input$t0) || !is.null(input$t1))) {
  biab_info("The chelsa collection has no temporal option. Extracting all chelsa items...")
}

# Load the CRS object
if (!is.null(CRS) & !is.null(input$spatial_res)) {
  coord <- st_crs(CRS)
  # Check for inconsistencies between CRS type and resolution
  if (st_is_longlat(coord) && input$spatial_res > 1) {
    biab_error_stop("CRS is in degrees and resolution is in meters.")
  }

  if (st_is_longlat(coord) == FALSE && input$spatial_res < 1) {
    biab_error_stop("CRS is in meters and resolution is in degrees.")
  }
}

# Convert date so it is in the correct format
if (!is.null(input$t0) | !is.null(input$t1)) {
  if (is.null(input$t0) | is.null(input$t1)) {
    biab_error_stop("Please provide both start and end date to filter by dates")
  }

  if (input$t0 >= input$t1) {
    biab_error_stop("Input years seem reversed. Please double check your inputs.")
  }

  if (is.null(input$temporal_res)) {
    biab_error_stop("Please provide a temporal resolution to filter by date.")
  }
  # Detect if t0 and t1 are just years (4 digits)
  if (grepl("^\\d{4}$", input$t0)) {
    input$t0 <- paste0(input$t0, "-01-01")
  }

  if (grepl("^\\d{4}$", input$t1)) {
    input$t1 <- paste0(input$t1, "-12-31")
  }

  t0 <- format(as_datetime(input$t0), "%Y-%m-%dT%H:%M:%SZ")
  t1 <- format(as_datetime(input$t1), "%Y-%m-%dT%H:%M:%SZ")
  datetime <- paste0(t0, "/", t1)
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
    stop("Please specify collections_items")
  } else {
    collections_items <- input$collections_items
  }
}

if (!("stac_url" %in% names(input))) {
  input$stac_url <- "https://stac.geobon.org"
}

# Connect to STAC
print("url output")
print(RCurl::url.exists(input$stac_url))

s <- rstac::stac(input$stac_url)

# initialize list for items

raster_paths <- c()

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

    if (is.null(CRS)) {
      srs.cube <- paste0("EPSG:", st_crs(r)$epsg)
    } else {
      srs.cube <- CRS
    }
    print(srs.cube)

    if (is.null(input$spatial_res)) {
      resolution <- res(r)
      resolution <- resolution[[1]]
    } else {
      resolution <- as.numeric(input$spatial_res)
    }
    print(resolution)

    # Make empty raster with desired resolution and extent
    empty_raster <- rast(xmin = bounding_box[1], xmax = bounding_box[3], ymin = bounding_box[2], ymax = bounding_box[4], resolution = resolution, crs = srs.cube)

    # Resample if crs or spatial resolution are not empty
    if (!is.null(input$spatial_res) | !is.null(CRS)) {
      resampled <- project(r, empty_raster)
    } else {
      resampled <- r
    }

    # Change band names if they are all called data
    if (names(resampled) == "data") {
      names(resampled) <- ci[2]
    }

    # Crop if there is a study area
    if (!is.null(input$study_area)) {
      study_area <- vect(poly)
      masked <- mask(resampled, study_area)
    } else {
      masked <- resampled
    }

    # Name file path, adds
    base_name <- names(masked)
    paths <- file.path(outputFolder, paste0(names(masked), ".tif"))
    print(paths)
    k <- 1
    while (file.exists(paths)) {
      paths <- file.path(outputFolder, paste0(base_name, "_", k, ".tif"))
      k <- k + 1
    }

    file <- writeRaster(masked, paths)

    #### Case 2: Pull all items in a collection ####
  } else { # if there are not collection items specified
    tryCatch(
      {
        it_obj <- s |>
          rstac::collections(coll_it) |>
          rstac::items() |>
          rstac::get_request() |>
          rstac::items_fetch() # connect to whole collection
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
    # get asset names
    asset_names <- lapply(it_obj$features, function(item) {
      names(item$assets)
    })
    asset_names <- unlist(asset_names)
    print("Asset names:")
    print(asset_names)

    # Extract spatial res if not provided
    if (is.null(input$spatial_res)) { # Obtain spatial resolution from metadata
      spatial.res <-
        print(it_obj$features[[1]]$assets$data$`raster:bands`[[1]]$spatial_resolution)
      print("Spatial.res:")
      print(spatial.res)

      if (st_is_longlat(coord) == FALSE && spatial.res < 1) {
      biab_error_stop("CRS is in meters and resolution is in degrees.")
      }

      if (st_is_longlat(coord) && spatial.res > 1) {
      biab_error_stop("CRS is in degrees and resolution is in meters.")
      }

    } else {
      spatial.res <- input$spatial_res
    }


    # Extract crs if not provided
    if (is.null(CRS)) { # Obtain CRS from metadata
      if ("proj:epsg" %in% names(it_obj$features[[1]]$properties)) {
        srs.cube <- paste0("EPSG:", it_obj$features[[1]]$properties$`proj:epsg`)
        print("srs_cube")
        print(srs.cube)
      } else if (`proj:wkt2` %in% names(it_obj$features[[1]]$properties)) {
        srs.cube <- it_obj$features[[1]]$properties$`proj:wkt2`
      }
    } else {
      srs.cube <- CRS
    }

    # Extract date
    dates <- vapply(it_obj$features, function(x) x$properties$`datetime`, character(1))
    if (!all(asset_names == asset_names[1])) { # pull whole collection if names of assets are different
      print(asset_names)
      paths <- c()
      for (i in 1:length(asset_names)) { # loop through items in a collection
        print("Pulling all items")
        asset <- asset_names[i]
        date_layer <- dates[i] # select asset date
        print(date_layer)
        print(asset)
        st <- gdalcubes::stac_image_collection(feats, asset_names = asset) # make stac image collection for each item in collection
        # Make a cube
        v <- gdalcubes::cube_view(
          srs = srs.cube,
          extent = list(
            left = xmin,
            right = xmax,
            top = ymax,
            bottom = ymin,
            t0 = min(date_layer), # will only pull layers from that date
            t1 = max(date_layer)
          ),
          dx = spatial.res,
          dy = spatial.res,
          dt = "P1D", # this doesn't matter because there is only one date per object
          aggregation = input$aggregation,
          resampling = input$resampling
        )

        raster_layers <- gdalcubes::raster_cube(st, v)

        if (!is.null(input$study_area)) {
          raster_layers <- filter_geom(raster_layers, poly$geom)
        }

        out <- gdalcubes::write_tif(raster_layers,
          dir = file.path(outputFolder), prefix = paste0(coll_it, "_", asset_names[i], "_"),
          creation_options = list("COMPRESS" = "DEFLATE"), COG = TRUE, write_json_descr = TRUE
        )
        paths <- out
      }
    } else { # If asset names are the same, filter by date (or tile if they are all the same date)
      st <- gdalcubes::stac_image_collection(feats, asset_names = "data") # make stac image collection
      print("filtering cube by date")

      if ((is.null(input$t0) && is.null(input$t1)) || min(dates) == max(dates)) { # If there is no time input or the dates are all the same
        dates_unique <- unique(dates)
        print(dates_unique)
        paths <- c()
        for (i in 1:length(dates_unique)) { # loop through dates
          date <- dates_unique[i] # select date
          v <- gdalcubes::cube_view(
            srs = srs.cube,
            extent = list(
              left = xmin,
              right = xmax,
              top = ymax,
              bottom = ymin,
              t0 = min(date),
              t1 = max(date)
            ),
            dx = spatial.res,
            dy = spatial.res,
            dt = "P1Y",
            aggregation = input$aggregation,
            resampling = input$resampling
          )

          raster_layers <- gdalcubes::raster_cube(st, v)

          if (!is.null(input$study_area)) {
            raster_layers <- filter_geom(raster_layers, poly$geom)
          }

          out <- gdalcubes::write_tif(raster_layers,
            dir = file.path(outputFolder), prefix = paste0(coll_it, "_"),
            creation_options = list("COMPRESS" = "DEFLATE"), COG = TRUE, write_json_descr = TRUE
          )
          paths <- out
        }
      } else {
        v <- gdalcubes::cube_view(
          srs = srs.cube,
          extent = list(
            left = xmin,
            right = xmax,
            top = ymax,
            bottom = ymin,
            t0 = input$t0,
            t1 = input$t1
          ),
          dx = spatial.res,
          dy = spatial.res,
          dt = input$temporal_res,
          aggregation = input$aggregation,
          resampling = input$resampling
        )
        raster_layers <- gdalcubes::raster_cube(st, v)

        if (!is.null(input$study_area)) {
          raster_layers <- filter_geom(raster_layers, poly$geom)
        }

        out <- gdalcubes::write_tif(raster_layers,
          dir = file.path(outputFolder), prefix = paste0(coll_it, "_"),
          creation_options = list("COMPRESS" = "DEFLATE"), COG = TRUE, write_json_descr = TRUE
        )
        paths <- out
      }
    }
  }
  raster_paths <- c(raster_paths, paths)
}

biab_output("rasters", raster_paths)
