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
           t0 =  format(lubridate::as_datetime('1900-01-01'), "%Y-%m-%dT%H:%M:%SZ"),
           t1 =  format(lubridate::as_datetime('2200-01-01'), "%Y-%m-%dT%H:%M:%SZ"),
           spatial.res = NULL,
           temporal.res = "P1Y",
           aggregation = "mean",
           resampling = "near") {
    s <- rstac::stac(stac_path)
    if (!inherits(bbox, "bbox"))
      stop("The bbox is not a bbox object.")
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

    tryCatch(
      {
        it_obj <- s |> rstac::collections(collections) |> rstac::items(ids) |> rstac::get_request()
      },
        error = function(cond) {
          message("ITEM NOT FOUND. Please check STAC url or collection and item names.")
          message(cond)
          # Choose a return value in case of error
          print(exiting)
        },
        finally = {
            message('Exiting.')
        }
    )
    
    if (!is.null(t0)) {
      datetime <- format(lubridate::as_datetime(t0), "%Y-%m-%dT%H:%M:%SZ")
    } else {
      datetime <- it_obj$properties$datetime
      t0 <- datetime
      t1 <- datetime
    }
    if (!is.null(t1) && t1 != t0) {
      datetime <- paste(datetime,
                        format(lubridate::as_datetime(t1),
                               "%Y-%m-%dT%H:%M:%SZ"),
                        sep = "/")
    } else {
      t1 <- t0
    }
    RCurl::url.exists(stac_path)
    name1 <- names(it_obj$assets)[1]

    if (is.null(spatial.res)) { # obtain spatial resolution from metadata
      spatial.res <-
        it_obj$assets[[name1]]$`raster:bands`[[1]]$spatial_resolution
    }
    if (is.null(srs.cube)) { # obtain spatial resolution from metadata
      if('proj:epsg' %in% names(it_obj$properties)){
        srs.cube <- paste0("EPSG:",it_obj$properties$`proj:epsg`)
      }else if (`proj:wkt2` %in% names(it_obj$properties)){
        srs.cube <- it_obj$properties$`proj:wkt2`
      }
    }
    if (is.null(layers)) {
      layers <- names(it_obj$assets)
    }
    if (!is.null(ids)) {
      feats<-it_obj
    }else{
      feats<-it_obj$features
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
      st <- gdalcubes::stac_image_collection(list(feats),asset_names = layers)
    }
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