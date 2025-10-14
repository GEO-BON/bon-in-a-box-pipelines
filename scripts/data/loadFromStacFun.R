load_cube <-
  function(stac_path = "https://stac.geobon.org/",
           limit = NULL,
           collections = c("chelsa-clim"),
           bbox = NULL,
           layers = NULL,
           variable = NULL,
           ids = NULL,
           mask = NULL,
           srs.cube = NULL,
           t0 = NULL,
           t1 = NULL,
           spatial.res = NULL,
           temporal.res = "P1Y",
           aggregation = "mean",
           resampling = "near") {
    s <- rstac::stac(stac_path)

    if (!inherits(bbox, "bbox")) {
      stop("The bbox is not a bbox object.")
    }
    left <- bbox$xmin
    right <- bbox$xmax
    bottom <- bbox$ymin
    top <- bbox$ymax
    if (left > right) {
      stop("left and right seem reversed")
    }
    if (bottom > top) {
      stop("bottom and top seem reversed")
    }

    ## Convert datetime input to be able to search
  if (!is.null(t0) && !is.null(t1)) {
    t0 <- format(as_datetime(t0), "%Y-%m-%dT%H:%M:%SZ")
    t1 <- format(as_datetime(t1), "%Y-%m-%dT%H:%M:%SZ")
    datetime <- if (t0 == t1) {
      t0
    } else {
      paste(t0, t1, sep = "/")
    }
  }

    tryCatch(
      ## Case 1: Collections and IDs provided
      if (!is.null(ids)) {
        it_obj <- s |>
          rstac::collections(collections) |>
          rstac::items(ids) |>
          rstac::get_request() 

        # Download items
      }
      # Case 2: Pull all items in a collection
      else if (is.null(ids) && is.null(t0) && is.null(t1)) {
     it_obj <- s |>
        rstac::collections("chelsa-clim") |>
        rstac::items() |>
        rstac::get_request() |>
        rstac::items_fetch()
      }
      # Case 3: Pull timeseries by t0 and t1
      else {
        it_obj <-
          s |>
          rstac::stac_search(collections,
            bbox = c(left, bottom, right, top),
            datetime = datetime
          ) |>
        #  rstac::get_request() |>
          rstac::items_fetch()
    #   },
    #   error = function(cond) {
    #     message("ITEM NOT FOUND. Please check STAC url or collection and item names.")
    #     message(cond)
    #     # Choose a return value in case of error
    #     print(exiting)
    #   },
    #   finally = {
    #     message("Exiting.")
    #   }
    # )

    RCurl::url.exists(stac_path)
    name1 <- names(it_obj$assets)[1]

    if (is.null(spatial.res)) { # Obtain spatial resolution from metadata
      spatial.res <-
        it_obj$assets[[name1]]$`raster:bands`[[1]]$spatial_resolution
    }

    if (is.null(srs.cube)) { # Obtain CRS from metadata
      if ("proj:epsg" %in% names(it_obj$properties)) {
        srs.cube <- paste0("EPSG:", it_obj$properties$`proj:epsg`)
      } else if (`proj:wkt2` %in% names(it_obj$properties)) {
        srs.cube <- it_obj$properties$`proj:wkt2`
      }
    }
    
    if (is.null(layers)) {
      layers <- names(it_obj$assets)
    }
    # Pull ids from layers if they are not provided
    if (!is.null(ids)) {
      feats <- it_obj
    } else {
      feats <- it_obj$features
    }


    if (!is.null(variable)) {
      print("Variable is null")
      st <- gdalcubes::stac_image_collection(
        list(feats),
        asset_names = layers,
        property_filter = function(x) {
          x[["variable"]] %in% variable
        }
      )
    } else {
      st <- gdalcubes::stac_image_collection(list(feats), asset_names = layers)
    }
 
 
 
#   if(is.null(t0) && is.null(t1)){
# if (!is.null(t0)) {
#       datetime <- format(lubridate::as_datetime(t0), "%Y-%m-%dT%H:%M:%SZ")
#     } else {
#       datetime <- it_obj$properties$datetime
#       t0 <- datetime
#       t1 <- datetime
#     }
#     if (!is.null(t1) && t1 != t0) {
#       datetime <- paste(datetime,
#         format(
#           lubridate::as_datetime(t1),
#           "%Y-%m-%dT%H:%M:%SZ"
#         ),
#         sep = "/"
#       )
#     } else {
#       t1 <- t0
#     }

### Stars and VSIcurl - in a loop to return multiple
## Then another option to be able to merge and tile

    v <- gdalcubes::cube_view(
      srs = srs.cube,
      extent = list(
        t0 = t0,
        t1 = t1,
        left = left,
        right = right,
        top = top,
        bottom = bottom
      ),
      dx = spatial.res,
      dy = spatial.res,
      dt = temporal.res,
      aggregation = aggregation,
      resampling = resampling
    ) 

    gdalcubes::gdalcubes_options(parallel = T)
    cube <- gdalcubes::raster_cube(st, v, mask)
    return(cube)
  }
