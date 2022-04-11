#' Create a proxy data cube for current climate, 
#' which loads data from a given image collection according to a data cube view based
#' on a specific box coordinates or using a set of observations
#' 
#' @name load_cube
#' 
#' @param stac_path, a character, base url of a STAC web service.
#' @param limit, an integer defining the maximum number of results to return. 
#' @param collections, a character vector of collection IDs to include
#' subsetLayers, a vector, containing the name of layers to select. If NULL, all layers in dir.pred selected by default.
#' @param use.obs, a boolean. If TRUE, the provided observations will be sued as a basis for calculating the extent and bbox.
#' @param obs, a data.frame containg the observations (used if use.obs is T)
#' @param srs.obs, string, observations spatial reference system. Can be a proj4 definition, WKT, or in the form "EPSG:XXXX".
#' @param lon, a string, column from obs containing longitude
#' @param lat, a string, column from obs containing latitude
#' @param buffer.box, an integer, buffer to apply around the obs to calculate extent and bbox
#' @param bbox, a numeric vector of size 4 or 6. Coordinates of the bounding box (if use.obs is FALSE). Details in rstac::stac_search documentation.
#' @param layers, a string vector, names of bands to be used,. By default (NULL), all bands with "eo:bands" attributes will be used. 
#' @param srs.cube, string, target spatial reference system. Can be a proj4 definition, WKT, or in the form "EPSG:XXXX".
#' @param t0, ISO8601 datetime string, start date.
#' @param t1, ISO8601 datetime string, end date.
#' @param left, a float. Left coordinate of the extent. Used if use.obs = F
#' @param right, a float. Right coordinate of the extent. Used if use.obs = F
#' @param top, a float. Top coordinate of the extent. Used if use.obs = F
#' @param bottom, a float. Bottom coordinate of the extent. Used if use.obs = F
#' @param spatial.res, a float, size of pixels in longitude and latitude directions, in the unit of srs.cube spatial reference system.
#' @param temporal.res, size of pixels in time-direction, expressed as ISO8601 period string (only 1 number and unit is allowed) such as "P16D"
#' @param aggregation, a character, aggregation method as string, defining how to deal with pixels containing data from multiple images, can be "min", "max", "mean", "median", or "first"
#' @param resampling, a character, resampling method used in gdalwarp when images are read, can be "near", "bilinear", "bicubic" or others as supported by gdalwarp (see https://gdal.org/programs/gdalwarp.html)
#' @return a raster stack of variables not intercorrelated
#' @import gdalcubes dplyr sp sf rstac
#' @return a proxy raster data cube

load_cube <- function(stac_path =
                        "http://io.biodiversite-quebec.ca/stac/",
                      limit = 5000,
                      collections = c('chelsa-clim'),
                      use.obs = T,
                      obs = NULL,
                      lon = "lon",
                      lat = "lat",
                      buffer.box = 0,
                      bbox = NULL,
                      layers = NULL,
                      srs.cube = "EPSG:32198", 
                      t0 = "1981-01-01", 
                      t1 = "1981-01-01",
                      spatial.res = 2000,
                      temporal.res  = "P1Y", 
                      aggregation = "mean",
                      resampling = "near") {
  
  # Creating RSTACQuery  query
  s <- rstac::stac(stac_path)
  
  # use observations to create the bbox and extent
  if (use.obs) {
    
    if (inherits(obs, "data.frame")) {
      # Reproject the obs to the data cube projection
      proj.pts <- project_coords(obs, lon = lon, lat = lat, proj.from = srs.cube)
      
    } else {
      proj.pts <- obs
    }
    
    # Create the extent (data cube projection)
    bbox.proj <- points_to_bbox(proj.pts, buffer = buffer.box)
    left <- bbox.proj$xmin
    right <- bbox.proj$xmax
    bottom <- bbox.proj$ymin
    top <- bbox.proj$ymax
    
    # Create the bbxo (WGS84 projection)
    bbox.wgs84 <- bbox.proj %>%
      sf::st_bbox(crs = srs.cube) %>%
      sf::st_as_sfc() %>%
      sf::st_transform(crs = 4326) %>%
      sf::st_bbox()
    
  } else {
    
    bbox.proj <- bbox
    left <- bbox.proj$xmin
    right <- bbox.proj$xmax
    bottom <- bbox.proj$ymin
    top <- bbox.proj$ymax
    
    if (left > right) stop("left and right seem reversed")
    if (bottom > top) stop("bottom and top seem reversed")
    
    
    bbox.wgs84 <- c(left, 
                    right,
                    top,
                    bottom) %>%
      sf::st_bbox(crs = srs.cube) %>%
      sf::st_as_sfc() %>%
      sf::st_transform(crs = 4326) %>%
      sf::st_bbox()
    
  }
  
  
  RCurl::url.exists(stac_path)
  
  if (!is.null(t0)) {
    # Create datetime object
    datetime <- format(lubridate::as_datetime(t0), "%Y-%m-%dT%H:%M:%SZ")
  } else {
    it_obj_tmp <- s |> #think changing it for %>%
      rstac::stac_search(bbox = bbox.wgs84, collections = collections, 
                         limit = limit) |> rstac::get_request()
    
    datetime <- it_obj_tmp$features[[1]]$properties$datetime
  }
  if (!is.null(t1) && t1 != t0) {
    datetime <- paste(datetime,
                      format(lubridate::as_datetime(t1), "%Y-%m-%dT%H:%M:%SZ"),
                      sep = "/")
    
  }
  
  # CreateRSTACQuery object with the subclass search containing all search field parameters 
  it_obj <- s |> #think changing it for %>%
    rstac::stac_search(bbox = bbox.wgs84, collections = collections, 
                       limit = limit, datetime = datetime) |> rstac::get_request()
  
  if (is.null(spatial.res)) {
    name1 <- unlist(lapply(it_obj$features, function(x){names(x$assets)}))[1]
    spatial.res <-  it_obj$features[[1]]$assets[[name1]]$`raster:bands`[[1]]$spatial_resolution
  }
  RCurl::url.exists(stac_path)
  
  # bbox in decimal lon/lat
  
  # If no layers is selected, get all the layers by default
  if (is.null(layers)) {
    layers <- unlist(lapply(it_obj$features, function(x){names(x$assets)}))
    
  }
  
  # Creates an image collection
  st <- gdalcubes::stac_image_collection(it_obj$features, asset_names = layers) 
  
  v <- gdalcubes::cube_view(srs = srs.cube,  extent = list(t0 = t0, t1 = t1,
                                                           left = left, right = right,
                                                           top = top, bottom = bottom),
                            dx = spatial.res, dy = spatial.res, dt = temporal.res, aggregation = aggregation, resampling = resampling)
  gdalcubes::gdalcubes_options(parallel = 4)
  cube <- gdalcubes::raster_cube(st, v)
  
  return(cube)
}


extract_cube_values <- function(cube, df, lon, lat, proj) {
 
 geom <- sf::st_as_sf(df, coords = c(lon, lat),
                           crs = proj) %>% dplyr::select(geometry)   
  print(geom)  
  print(cube)  
                                                           
  value_points <- gdalcubes::extract_geom(cube, geom) 
  plot(head(value_points))
  df <- df %>% dplyr::mutate(FID = as.integer(rownames(df)))
  df.vals <- dplyr::right_join(df, value_points, by = c("FID")) %>%
       dplyr::select(-FID)
  return(df.vals)
  
}

cube_to_raster <- function(cube, format = "raster") {
  # Transform to a star object
  cube.xy <- cube %>%
    stars::st_as_stars()
  

  # We remove the temporal dimension
  cube.xy <- cube.xy %>% abind::adrop(c(F,F,T))
  
  # Conversion to a spatial object
  
  if (format == "raster") {
    # Raster format
    cube.xy <- raster::stack(as(cube.xy, "Spatial"))
    
  } else {
    # Terra format
    cube.xy <- terra::rast(cube.xy)
  }
  # If not, names are concatenated with temp file names
  names(cube.xy) <- names(cube)
  
  cube.xy
  
}

add_predictors <- function(obs, lon = "lon", lat = "lat", predictors){
  if (inherits(predictors, "cube")) {
    predictors <- cube_to_raster(predictors, format = "terra")
  }
  env.vals <- terra::extract(predictors, dplyr::select(obs, dplyr::all_of(c(lon, lat))))
  obs <- dplyr::bind_cols(obs,
                          env.vals) %>% dplyr::select(-ID)
  
  return(obs)
  }


