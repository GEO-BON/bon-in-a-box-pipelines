## Function to load cube (pulled from stacatalog package)
library(gdalcubes)
setwd(outputFolder)

### Load cube func
load_cube <-
  function(stac_path = "https://io.biodiversite-quebec.ca/stac/",
           limit = NULL,
           collections = c("chelsa-clim"),
           bbox = NULL,
           layers = NULL,
           variable = NULL,
           ids = NULL,
           mask = NULL,
           srs.cube = "EPSG:6623",
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
    bbox.wgs84 <-
      bbox %>% sf::st_bbox(crs = srs.cube) %>% sf::st_as_sfc() %>%
      sf::st_transform(crs = "EPSG:4326") %>% sf::st_bbox()
    if (!is.null(t0)) {
      datetime <- format(lubridate::as_datetime(t0), "%Y-%m-%dT%H:%M:%SZ")
    } else {
      it_obj_tmp <- s %>% rstac::stac_search(bbox = bbox.wgs84,
                                             collections = collections,
                                             limit = limit) %>% rstac::get_request()
      datetime <- it_obj_tmp$features[[1]]$properties$datetime
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
    it_obj <-
      s %>% rstac::stac_search(
        bbox = bbox.wgs84,
        collections = collections,
        datetime = datetime,
        limit = limit
      ) %>% rstac::get_request()
  # Force each dataset to have the data role. Fix 08/2023
    for (i in 1:length(it_obj$features)){
        it_obj$features[[i]]$assets[[1]]$roles<-'data'
    }
    

    if (is.null(spatial.res)) {
      name1 <- unlist(lapply(it_obj$features, function(x) {
        names(x$assets)
      }))[1]
      spatial.res <-
        it_obj$features[[1]]$assets[[name1]]$`raster:bands`[[1]]$spatial_resolution
    }
    if (is.null(layers)) {
      layers <- unlist(lapply(it_obj$features, function(x) {
        names(x$assets)
      }))
    }
    if (!is.null(ids)) {
      feats<-it_obj$features[lapply(it_obj$features,function(f){f$id %in% ids})==TRUE]
      print(feats[ids])
    }else{
      feats<-it_obj$features
    }
    print(ids)
    if (!is.null(variable)) {
      print("Variable is null")
      st <- gdalcubes::stac_image_collection(
        feats,
        asset_names = layers,
        property_filter = function(x) {
          x[["variable"]] %in% variable
        }
      )
    } else {
      st <- gdalcubes::stac_image_collection(feats ,
                                             asset_names = layers)
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


#### Cube to raster func
cube_to_raster <- function(cube, format = "raster") {
  # Transform to a star object
  cube.xy <- cube %>%
    stars::st_as_stars()
  
  # If not, names are concatenated with temp file names
  
  # We remove the temporal dimension
  cube.xy <- cube.xy %>% abind::adrop(c(F, F, T))
  
  # Conversion to a spatial object
  
  if (format == "raster") {
    # Raster format
    cube.xy <- raster::stack(as(cube.xy, "Spatial"))
  } else {
    # Terra format
    cube.xy <- terra::rast(cube.xy)
  }
  names(cube.xy) <- names(cube)
  
  cube.xy
}