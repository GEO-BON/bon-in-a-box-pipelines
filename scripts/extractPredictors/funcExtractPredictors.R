

#' @name projectCoords
#' @param xy data frame, containing the coordinates to reproject
#' @param lon string, name of the longitude column
#' @param lat string, name of the latitude column
#' @param proj.from character, initial projection of the xy coordinates
#' @param proj.to character, target projection 
#' @return spatial points in the proj.to projection

projectCoords <- function(xy, lon = "lon", lat = "lat", proj.from, proj.to) {
  xy <- dplyr::select(xy, all_of(c(lon, lat)))
  sp::coordinates(xy) <-  c(lon, lat)
  proj4string(xy) <- sp::CRS(proj.from)
  xy <- sp::spTransform(xy, sp::CRS(proj.to)) 
  xy
}


#' @name findBox
#' @param xy data frame, containing the coordinates to reproject
#' @param buffer integer, buffer to add around the observations
#' @param proj.from character, initial projection of the xy coordinates
#' @param proj.to character, target projection 
#' @return a box extent
findBox <- function(xy, buffer = 0, proj.from = NULL, proj.to = NULL) {
  if (class(xy) != "SpatialPoints") {
    sp::coordinates(xy) <- colnames(xy)
    proj4string(xy) <- sp::CRS(proj.from)
  }
  bbox <-  sf::st_buffer(sf::st_as_sfc(sf::st_bbox(xy)), dist =  buffer)
  
  if (!is.null(proj.to) ) {
    bbox <- bbox  %>%
      sf::st_transform(crs = sp::CRS(proj.to))
  }
  bbox <- c(sf::st_bbox(bbox)$xmin, sf::st_bbox(bbox)$xmax,
            sf::st_bbox(bbox)$ymin, sf::st_bbox(bbox)$ymax)
  bbox
}





sampleGdalCube <- function(cube, date, n.sample) {
  
  x <- dimension_values(cube)$x
  y <- dimension_values(cube)$y
  
  all.points <- expand.grid(x,y) %>% setNames(c("x", "y"))
  sample.points <- all.points[sample(1:nrow(all.points), n.sample),]
  t <- rep(as.Date(date), nrow(sample.points) )
  
  value.points <- query_points(cube, sample.points$x, sample.points$y, t, srs(cube))
  value.points
}




## Install required packages



# Load functions
projectCoords <- function(xy, lon, lat, proj.i = "+proj=longlat +datum=WGS84", proj.y) {
  sp::coordinates(xy) <- c(lon, lat)
  proj4string(xy) <- CRS(proj.i)
  xy <- spTransform(xy, CRS(proj.y))
  xy
}

sampleGdalCube <- function(cube, lon, lat, date) {
  
  x <- dimension_values(cube)$x
  y <- dimension_values(cube)$y
  
  all.points <- expand.grid(x,y) %>% setNames(c("x", "y"))
  sample.points <- all.points[sample(1:nrow(all.points), n.sample),]
  t <- rep(as.Date(date), nrow(sample.points) )
  
  value.points
}

#' Create a proxy data cube for current climate, 
#' which loads data from a given image collection according to a data cube view based
#' on a specific box coordinates or using a set of observations
#' 
#' @name loadCube
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
#' @import gdalcubes, dplyr, sp, sf, rstac
#' @return a proxy raster data cube

loadCube <- function(stac_path =
                       "http://io.biodiversite-quebec.ca/stac/",
                     limit = 5000,
                     collections = c('chelsa-clim'),
                     use.obs = T,
                     obs = NULL,
                     srs.obs = NULL,
                     lon = "lon",
                     lat = "lat",
                     buffer.box = 0,
                     bbox = NULL,
                     layers = NULL,
                     srs.cube = "EPSG:32198", 
                     t0 = "1981-01-01", 
                     t1 = "1981-01-01",
                     left = -2009488, right = 1401061,  bottom = -715776, top = 2597757,
                     spatial.res = 2000,
                     temporal.res  = "P1Y", 
                     aggregation = "mean",
                     resampling = "near") {
  
  # Creating RSTACQuery  query
  s <- rstac::stac(stac_path)
  
  # use observations to create the bbox and extent
  if (use.obs) {
    
    if ("data.frame" %in% class(obs)) {
      # Reproject the obs to the data cube projection
      proj.pts <- projectCoords(obs, lon = lon, lat = lat, proj.from = srs.obs, proj.to = srs.cube)
      
    } else {
      proj.pts <- obs
    }

    # Create the extent (data cube projection)
    bbox.proj <- findBox(proj.pts, buffer = buffer.box)
    left <- bbox.proj[1]
    right <- bbox.proj[2]
    bottom <- bbox.proj[3]
    top <- bbox.proj[4]
    
    # Create the bbxo (WGS84 projection)
    bbox.wgs84 <- findBox(proj.pts, buffer = buffer.box, proj.to ="+proj=longlat +datum=WGS84")
    
  }
  
  # CreateRSTACQuery object with the subclass search containing all search field parameters 
  it_obj <- s |>
    rstac::stac_search(bbox = bbox.wgs84, collections = collections, limit = limit) |> get_request() # bbox in decimal lon/lat
  
  # If no layers is selected, get all the layers by default
  if (is.null(layers)) {
    layers <- unlist(lapply(it_obj$features,function(x){names(x$assets)}))
    
  }
  
  # Creates an image collection
  st <- gdalcubes::stac_image_collection(it_obj$features, asset_names = layers) 

  v <- gdalcubes::cube_view(srs = srs.cube,  extent = list(t0 = t0, t1 = t1,
                                           left = left, right = right,  top = top, bottom = bottom),
                 dx = spatial.res, dy = spatial.res, dt = temporal.res, aggregation = aggregation, resampling = resampling)
  gdalcubes_options(threads = 4)
  cube <- gdalcubes::raster_cube(st, v)

  return(cube)
}



#' Extract values of a proxy raster data cube
#' 
#' @name extractCubeValues
#' 
#' @param cube, a proxy raster data cube (raster_cube object, or output of loadCube)
#' @param points, spatial points object from which to extract values, in the same projection system as the data cube
#' @param date, ISO8601 datetime string, same as t0 used to load raster cube
#' @import gdalcubes
#' @return a data.frame containing values (one row per points in points, one column per varieble -or layer-)

extractCubeValues <- function(cube, points, date) {

  value.points <- gdalcubes::query_points(cube, points@coords[,1],
                                          points@coords[,2],
                                          pt = rep(as.Date(date),length(points@coords[,1])), 
                                          srs(cube))
    

  return(value.points)
}


#' Create a proxy data cube for future climate, 
#' which loads data from a given image collection according to a data cube view based
#' on a specific box coordinates or using a set of observations
#' 
#' @name loadCubeProjection
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
#' @param rcp, ISO8601 datetime string, end date.
#' @param t0, ISO8601 datetime string, end date.
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

loadCubeProjection <- function(stac_path =
                                 "http://io.biodiversite-quebec.ca/stac/",
                               limit = 5000,
                               collections = c('chelsa-clim-proj'),
                               use.obs = T,
                               obs = NULL,
                               srs.obs = "+proj=longlat +datum=WGS84",
                               lon = "lon",
                               lat = "lat",
                               buffer.box = 0,
                               bbox = NULL,
                               layers = NULL,
                               srs.cube = "EPSG:32198",  
                               time.span = "2041-2070",
                               rcp = "ssp585",
                               t0 = "2041-01-01",
                               left = -2009488, right = 1401061,  bottom = -715776, top = 2597757,
                               spatial.res = 2000,
                               temporal.res  = "P1Y", aggregation = "mean",
                               resampling = "near") {
  s <- stac(stac_path)
  
  if (use.obs) {
    
    if ("data.frame" %in% class(obs)) {
      # Reproject the obs to the data cube projection
      proj.pts <- projectCoords(obs, lon = lon, lat = lat, proj.from = srs.obs, proj.to = srs.cube)
      
    } else {
      proj.pts <- obs
    }

    bbox <- findBox(proj.pts, buffer = buffer.box, proj.to ="+proj=longlat +datum=WGS84")
    bbox.proj <- findBox(proj.pts, buffer = buffer.box)
    left <- bbox.proj[1]
    right <- bbox.proj[2]
    bottom <- bbox.proj[3]
    top <- bbox.proj[4]
  }
  
  it_obj <- s |>
    stac_search(bbox = bbox, collections = collections, limit = limit) |> get_request() # bbox in decimal lon/lat
  
  all.layers <- unlist(lapply(it_obj$features,function(x){names(x$assets)}))
  
  
  st <- stac_image_collection(it_obj$features, asset_names = all.layers,
                              property_filter = function(x) {x[["variable"]] %in% layers & x[["time_span"]] == time.span  & x[["rcp"]] == rcp })
  
  #if layers = NULL, load all the layers
  v <- cube_view(srs = srs.cube,  extent = list(t0 = t0, t1 = t0,
                                           left = left, right = right,  top = top, bottom = bottom),
                 dx = spatial.res, dy = spatial.res, dt = temporal.res, aggregation = aggregation, resampling = resampling)
  gdalcubes_options(threads = 4)
  cube <- raster_cube(st, v)
  return(cube)
}


#' Pivot the data.frame containing bioclim variable extracted from future projections (several models)
#' @name extractBio
#' @param df, a dataframe containing climatic variable values, type "bio" (e.g. bio1, bio6...)
#' @return a data.frame

extractBio <- function(df) {
  df <- df %>% pivot_longer(
    cols = starts_with("bio"),
    names_to = c("variable", "year", "model", "scenario"), 
    names_pattern = "(.*)_(.*)_(.*)_(.*)",
    values_to = "value"
  )
  return(df)
}

#' Aggreg the values of one or several variables among serval climatic models
#' using a user-defined function (mean, median, min, or max)
#' @name aggregModels
#' @param df, a dataframe with climatic values among several models
#' @param grp, list of colums used to aggregate
#' @param fun, function to apply to summarise models values (mean, median, min, or max)
#' @return a data.frame with one biloclim var per column, aggregated among models
#' 
aggregModels <- function(df, grp = c("lon", "lat", "variable"), fun = "mean") {
  
  match.arg(fun, choices = c("mean", "median", "max", "min"))
  
  if (fun == "mean") {
    df.agg <- df %>% group_by(across(all_of(grp))) %>% summarise(mean = mean(value))
    
  } else if (fun == "median") {
    df.agg <- df %>% group_by(across(all_of(grp))) %>% summarise(median = median(value))
    
  } else if (fun == "min") {
    df.agg <- df %>% group_by(across(all_of(grp))) %>% summarise(min = min(value))
    
  } else if (fun == "max") {
    df.agg <- df %>% group_by(across(all_of(grp))) %>% summarise(max = max(value))
    
  } 
  
  df.agg <- df.agg %>%
     pivot_wider(names_from = variable, values_from = all_of(fun))
  
  return(df.agg)
}

