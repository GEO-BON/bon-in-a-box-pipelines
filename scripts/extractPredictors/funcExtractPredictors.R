



sampleGdalCube <- function(cube, date, n.sample) {
  
  x <- dimension_values(cube)$x
  y <- dimension_values(cube)$y
  
  all.points <- expand.grid(x,y) %>% setNames(c("x", "y"))
  sample.points <- all.points[sample(1:nrow(all.points), n.sample),]
  t <- rep(as.Date(date), nrow(sample.points) )
  
  value.points <- query_points(cube, sample.points$x, sample.points$y, t, srs(cube))
  value.points
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

    bbox <- points_to_bbox(proj.pts, buffer = buffer.box, proj.to ="+proj=longlat +datum=WGS84")
    bbox.proj <- points_to_bbox(proj.pts, buffer = buffer.box)
    left <- bbox.proj[1]
    right <- bbox.proj[2]
    bottom <- bbox.proj[3]
    top <- bbox.proj[4]
  }
  
  it_obj <- s |>
    rstac::stac_search(bbox = bbox, collections = collections, limit = limit) |>  rstac::get_request() # bbox in decimal lon/lat
  
  all.layers <- unlist(lapply(it_obj$features,function(x){names(x$assets)}))
  
  
  st <- gdalcubes::stac_image_collection(it_obj$features, asset_names = all.layers,
                              property_filter = function(x) {x[["variable"]] %in% layers & x[["time_span"]] == time.span  & x[["rcp"]] == rcp })
  
  #if layers = NULL, load all the layers
  v <- gdalcubes:cube_view(srs = srs.cube,  extent = list(t0 = t0, t1 = t0,
                                           left = left, right = right,  top = top, bottom = bottom),
                 dx = spatial.res, dy = spatial.res, dt = temporal.res, aggregation = aggregation, resampling = resampling)
  gdalcubes::gdalcubes_options(parallel = 4)
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
