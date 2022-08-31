#' Create a proxy data cube for current climate, 
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
    proj.pts <- projectCoords(obs, lon = lon, lat = lat, proj.from = srs.obs, proj.to = srs.cube)
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
  v <- cube_view(srs = srs,  extent = list(t0 = t0, t1 = t0,
                                           left = left, right = right,  top = top, bottom = bottom),
                 dx = spatial_res, dy = spatial.res, dt = temporal.res, aggregation = aggregation, resampling = resampling)
  gdalcubes_options(threads = 4)
  cube <- raster_cube(st, v)
  return(cube)
}
