
#' @name create_projection
#' @param lon string, name of the longitude column
#' @param lat string, name of the latitude column
#' @param proj_from character, initial projection of the xy coordinates
#' @param proj_to character, target projection
#' @param new_lon character, name of the new longitude column
#' @param new_lat character, name of the new latitude column
#' @return a dataframe with two columns in the proj_to projection
#' @import dplyr
#' 
create_projection <- function(obs, lon, lat, proj_from, 
                              proj_to, new_lon = NULL, new_lat = NULL) {
  
  if(is.null(new_lon)) {
    new_lon <- lon
  }
  
  if(is.null(new_lat)) {
    new_lat <- lat
  }
  
  new.coords <- project_coords(obs, lon, lat, proj_from, proj_to)
  new.coords.df <- data.frame(new.coords) %>% 
    setNames(c(new_lon, new_lat))
  
  suppressWarnings(obs <- obs %>%
                     dplyr::select(-one_of(c(new_lon, new_lat))) %>% dplyr::bind_cols(new.coords.df))
  
  return(obs)
}

#' @name project_coords
#' @param xy data frame, containing the coordinates to reproject
#' @param lon string, name of the longitude column
#' @param lat string, name of the latitude column
#' @param proj_from character, initial projection of the xy coordinates
#' @param proj_to character, target projection
#' @import sp dplyr
#' @return spatial points in the proj_to projection

project_coords <- function(xy, lon = "lon", lat = "lat", proj_from, proj_to = NULL) {
  xy <- dplyr::select(xy, dplyr::all_of(c(lon, lat)))
  sp::coordinates(xy) <-  c(lon, lat)
  sp::proj4string(xy) <- sp::CRS(proj_from)
  
  if (!is.null(proj_to)) {
    xy <- sp::spTransform(xy, sp::CRS(proj_to)) 
    
  }
  xy
}

#' @name points_to_bbox
#' @param xy data frame, containing the coordinates to reproject
#' @param buffer integer, buffer to add around the observations
#' @param proj_from character, initial projection of the xy coordinates
#' @param proj_to character, target projection 
#' @return a box extent
points_to_bbox <- function(xy, buffer = 0, proj_from = NULL, proj_to = NULL) {
  if (!inherits(xy, "SpatialPoints")) {
    sp::coordinates(xy) <- colnames(xy)
    proj4string(xy) <- sp::CRS(proj_from)
  }
  bbox <-  sf::st_buffer(sf::st_as_sfc(sf::st_bbox(xy)), dist =  buffer)
  
  if (!is.null(proj_to) ) {
    bbox <- bbox  %>%
      sf::st_transform(crs = sp::CRS(proj_to))
  }
  
  bbox %>% sf::st_bbox()
}


shp_to_bbox <- function(shp, proj_from = NULL, proj_to = NULL) {
  if(is.na(sf::st_crs(shp)) && is.null(proj_from)) {
    stop("proj.fom is null and shapefile has no crs.")
  }
  
  if(is.na(sf::st_crs(shp))) {
    crs(shp) <- proj_from
    shp <- shp %>% sf::st_set_crs(proj_from)
  }
  
  if (!is.null(proj_to) ) {
    shp <- shp %>%
      sf::st_transform(crs = sp::CRS(proj_to))
  }
  
  
  bbox <- sf::st_bbox(shp, crs = proj)

  bbox
}


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
                      variable = NULL,
                      srs.cube = "EPSG:32198", 
                      t0 = "1981-01-01", 
                      t1 = "1981-01-01",
                      spatial.res = 2000,
                      temporal.res  = "P1Y", 
                      aggregation = "mean",
                      resampling = "near") {
  
  # Creating RSTACQuery  query
  s <- rstac::stac(stac_path)
  
  if (use.obs) {
    
    if (inherits(obs, "data.frame")) {
      # Reproject the obs to the data cube projection
      proj.pts <- project_coords(obs, lon = lon, lat = lat, proj_from = srs.cube)
      
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
  
  
  
  
  if (!is.null(t0)) {
    # Create datetime object
    datetime <- format(lubridate::as_datetime(t0), "%Y-%m-%dT%H:%M:%SZ")
  } else {
    it_obj_tmp <- s |> #think changing it for %>%
      rstac::stac_search(bbox = bbox.wgs84, collections = collections, 
                         limit = limit) |> rstac::get_request()
    
    datetime <- it_obj_tmp$features[[1]]$properties$datetime
    t0 <- datetime
    t1 <- datetime
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
  
  # 
  # Creates an image collection
  if(!is.null(variable)) {
    st <- gdalcubes::stac_image_collection(it_obj$features, asset_names = layers, 
                                           property_filter = function(x) {x[["variable"]] %in% variable}) 
    
  } else {
    st <- gdalcubes::stac_image_collection(it_obj$features, asset_names = layers) 
    
  }
  
  v <- gdalcubes::cube_view(srs = srs.cube,  extent = list(t0 = t0, t1 = t1,
                                                           left = left, right = right,
                                                           top = top, bottom = bottom),
                            dx = spatial.res, dy = spatial.res, dt = temporal.res, aggregation = aggregation, resampling = resampling)
  gdalcubes::gdalcubes_options(parallel = 4)
  cube <- gdalcubes::raster_cube(st, v)
  
  return(cube)
}



#' Create a proxy data cube for future climate, 
#' which loads data from a given image collection according to a data cube view based
#' on a specific box coordinates or using a set of observations
#' 
#' @name load_cube_projection
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
#' @param time.span, a string, time interval of the projection model.
#' @param rcp, a string, climatic scenario
#' @param left, a float. Left coordinate of the extent. Used if use.obs = F
#' @param right, a float. Right coordinate of the extent. Used if use.obs = F
#' @param top, a float. Top coordinate of the extent. Used if use.obs = F
#' @param bottom, a float. Bottom coordinate of the extent. Used if use.obs = F
#' @param spatial.res, a float, size of pixels in longitude and latitude directions, in the unit of srs.cube spatial reference system.
#' @param temporal.res, size of pixels in time-direction, expressed as ISO8601 period string (only 1 number and unit is allowed) such as "P16D"
#' @param aggregation, a character, aggregation method as string, defining how to deal with pixels containing data from multiple images, can be "min", "max", "mean", "median", or "first"
#' @param resampling, a character, resampling method used in gdalwarp when images are read, can be "near", "bilinear", "bicubic" or others as supported by gdalwarp (see https://gdal.org/programs/gdalwarp.html)
#' @return a raster stack of variables not intercorrelated
#' @import gdalcubes, dplyr, sp, sf, rstac
#' @return a proxy raster data cube

load_cube_projection <- function(stac_path =
                                 "http://io.biodiversite-quebec.ca/stac/",
                               limit = 5000,
                               collections = c('chelsa-clim-proj'),
                               use.obs = T,
                               obs = NULL,
                               lon = "lon",
                               lat = "lat",
                               buffer.box = 0,
                               bbox = NULL,
                               layers = NULL,
                               variable = NULL,
                               srs.cube = "EPSG:32198",  
                               time.span = "2041-2070",
                               rcp = "ssp585",
                               left = -2009488, right = 1401061,  bottom = -715776, top = 2597757,
                               spatial.res = 2000,
                               temporal.res  = "P1Y", aggregation = "mean",
                               resampling = "near") {
  
  #t0 param
  if (time.span == "2011-2040") {
    t0 <- "2011-01-01"
  }
  
  if (time.span == "2041-2070") {
    t0 <- "2041-01-01"
  }
  
  if (time.span == "2071-2100") {
    t0 <- "2071-01-01"
  }
  
  datetime <- format(lubridate::as_datetime(t0), "%Y-%m-%dT%H:%M:%SZ")
  s <- stac(stac_path)
  
   if (use.obs) {
     
     if (inherits(obs, "data.frame")) {
       # Reproject the obs to the data cube projection
       proj.pts <- project_coords(obs, lon = lon, lat = lat, proj_from = srs.cube)
       
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
   
  
  it_obj <- s |>
    stac_search(bbox = bbox.wgs84, collections = collections, limit = limit, datetime = datetime) |> get_request() # bbox in decimal lon/lat
  
  # If no layers is selected, get all the layers by default
  if (is.null(layers)) {
    layers <- unlist(lapply(it_obj$features, function(x){names(x$assets)}))
    
  }
  
  # 
  # Creates an image collection
  if(!is.null(variable)) {
    st <- gdalcubes::stac_image_collection(it_obj$features, asset_names = layers, 
                                           property_filter = function(x) {x[["variable"]] %in% variable & x[["rcp"]] == rcp}) 
    
  } else {
    st <- gdalcubes::stac_image_collection(it_obj$features, asset_names = layers, 
                                           property_filter = function(x) {x[["rcp"]] == rcp}) 
    
  }
  
  
  #if layers = NULL, load all the layers
  v <- cube_view(srs = srs.cube,  extent = list(t0 = t0, t1 = t0,
                                           left = left, right = right,  top = top, bottom = bottom),
                 dx = spatial.res, dy = spatial.res, dt = temporal.res, aggregation = aggregation, resampling = resampling)
  gdalcubes_options(threads = 4)
  cube <- raster_cube(st, v)
  return(cube)
}




cube_to_raster <- function(cube, format = "raster") {
  # Transform to a star object
  cube.xy <- cube %>%
    stars::st_as_stars()
  
  # If not, names are concatenated with temp file names
  names(cube.xy) <- names(cube)
  
  # We remove the temporal dimension
  cube.xy <- cube.xy|> abind::adrop(c(F,F,T))
  
  # Conversion to a spatial object
  
  if (format == "raster") {
    # Raster format
    cube.xy <- raster::stack(as(cube.xy, "Spatial"))
    
  } else {
    # Terra format
    cube.xy <- terra::rast(cube.xy)
  }
  
  cube.xy
  
}



extract_gdal_cube <- function(cube, n_sample = 5000, simplify = T) {
  
  x <- gdalcubes::dimension_values(cube)$x
  y <- gdalcubes::dimension_values(cube)$y
  
  all_points <- expand.grid(x,y) %>% setNames(c("x", "y"))
  
  if (n_sample >= nrow(all_points)) {
    value_points <- gdalcubes::extract_geom(cube, sf::st_as_sf(all_points, coords = c("x", "y"),
                                               crs = srs(cube))) 
  } else {
    sample_points <- all_points[sample(1:nrow(all_points), n_sample),]
    value_points <- gdalcubes::extract_geom(cube, sf::st_as_sf(sample_points, coords = c("x", "y"),
                                                               crs = srs(cube))) 
  }
  
  if (simplify) {
    value_points <- value_points %>% dplyr::select(-FID, -time)
  }
  value_points
}




get_info_collection <- function(stac_path =
                              "http://io.biodiversite-quebec.ca/stac/",
                            limit = 5000,
                            collections = c('chelsa-clim'),
                            bbox = NULL) {
  
  # Creating RSTACQuery  query
  s <- rstac::stac(stac_path)
  
  if(is.null(bbox)) {
    bbox <- c(xmin = -180, 
              xmax = 180,
              ymax = 180,
              ymin = -180)
  }

  
  # CreateRSTACQuery object with the subclass search containing all search field parameters 
  it_obj <- s |> #think changing it for %>%
    rstac::stac_search(bbox = bbox, collections = collections, 
                       limit = limit) |> rstac::get_request()
  
  layers <- unlist(lapply(it_obj$features, function(x){names(x$assets)}))
  temporal_extent <- unlist(lapply(it_obj$features, function(x){x$properties$datetime}))
  variable <- unique(unlist(lapply(it_obj$features, function(x){x$properties$variable})))
  t0 <- min(temporal_extent)
  t1 <- max(temporal_extent)
  spatial_res <-  unique(unlist(lapply(it_obj$features, 
                                       function(x){lapply(x$assets, 
                                       function(x){lapply(x$`raster:bands`,
                                       function(x){x$spatial_resolution})})}), use.names = F))

  return(list("layers"= layers, "variable" = variable, "t0" = t0, "t1" = t1, "spatial_resolution" = spatial_res))
}

