
#'
#' @title Create background points
#' 
#' @description 
#' Generates background points using any of the six available methods.
#' 
#' @details
#' When `method = "random"`, background points are randomly sampled throughout the whole study extent. When `method = "weighted_raster"`, background points are sampled in proportion to the number of observations of a target group in an observation density raster. When `method = "unweighted_raster"`, background points are sampled only in cells where there are observations from a target group. With `method = "inclusion_buffer"`, background points are sampled within a buffer around observations (to be confirmed...). With `method = "thickening"`, background points are sampled in proportion the local density of observations by sampling in a buffer around each observation (to be confirmed...). Finally, when `method = "biased"`, a `density_bias` raster representing the effort is given and background points are sampled in proportion to this raster (to be confirmed...).  
#'
#' @name create_background
#' @param predictors SpatRasterr, containing the predictor variables
#' @param mask SpatVector, mask to apply to the predictors.
#' @param method one of "random","weighted_raster","unweighted_raster","inclusion_buffer","biased","thickening".
#' @param n integer, number of background points to sample.
#' @param obs data.frame, containing the observations. Used with "thickening" or "inclusion_buffer".
#' @param density_bias SpatRaster giving an effort/bias surface from which background points are sampled
#' @param width_buffer int, buffer width around observations.  Used with "thickening" or "inclusion_buffer".
#' @param raster SpatRaster, raster heatmap used for weighted or unweighted sampling, default NULL when not using those methods
#' @return spatial points
#' @export

create_background <- function(
    predictors,
    mask = NULL,
    method = c("random","weighted_raster","unweighted_raster","inclusion_buffer","biased","thickening"),
    n = 10000,  
    obs = NULL,
    density_bias = NULL,
    width_buffer = NULL,
    raster = NULL) {
  
  method <- match.arg(method)
  
  proj <- terra::crs(predictors)
  
  ## New method: If we use raster, we re-project our raster and add it as an additional layer
  if (grepl("raster", method)) {
    if (is.null(raster)) stop(paste("No raster included with method:", method))
  }
  
  if (method == "biased") {
    if (is.null(density_bias)) stop(paste("No density_bias included with method:", method))
  }
  
  if (!is.null(mask)) {
    predictors <- fast_crop(predictors, mask)
  }
  
  if (method %in% c("inclusion_buffer","thickening")){
    ### Not sure why the following buffer width method was originally used. package FNN could be faster for searching nearest neighbours.
    #message("Argument width_buffer not provided. Using the 95% quantile 
    #  of the nearest neighbour distance that is not in the same location.")
    #
    #if(nrow(obs) > 1000){
    #  sampled_obs <- sample(1:nrow(obs), min(1000, nrow(obs)))
    #  message("Only 1000 randomly sampled locations are used to determine the width_buffer.")
    #}else{
    #  sampled_obs <- 1:nrow(obs)
    #}
    #width_buffer<-quantile(st_distance(obs[sampled_obs,]),0.95)
    #  
    #width_buffer<-obs[sampled_obs,] |>
    #                st_distance() |> 
    #                apply(2,function(x){min(x[x>0])}) |> 
    #                quantile(0.95)
    #  
    #message(sprintf("width-buffer used is %s (in the units of the crs)", width_buffer))
    
    if (is.null(obs)){
      stop(paste("No obs included with method:", method))
    }
    
    obs <- st_as_sf(obs, coords=c("lon", "lat"), crs = proj)
    
    if(is.null(width_buffer)){
      width_buffer <- 0.1 * max(diff(st_bbox(obs)[c(1, 3)]),diff(st_bbox(obs)[c(2, 4)]))
      message(sprintf("width_buffer used is 10%% of the largest bounding box dimension (%s in the units of the crs)", round(width_buffer)))
    }
    
  }
  
  backgr<-switch(method,
                 random = {
                   terra::spatSample(predictors[[1]], size = n, method = "random", replace = TRUE, values = FALSE, as.points = TRUE)
                 },
                 weighted_raster = {
                   terra::spatSample(raster, size = n, method = "weights", replace = TRUE, values = FALSE, as.points = TRUE)
                 },
                 unweighted_raster = {
                   terra::spatSample(raster > 0, size = n, method = "weights", replace = TRUE, values = FALSE, as.points = TRUE)
                 },
                 inclusion_buffer = { # this thing can take a while if there are many observations
                   obs |> 
                     st_buffer(dist = width_buffer, nQuadSegs = 10) |> 
                     st_union() |> 
                     st_sample(n) |> 
                     st_as_sf()
                 },
                 biased = { # not sure how this method differs from weighted_raster, ignored at the moment as an option
                   terra::spatSample(density_bias, size = n, method = "weights", replace = TRUE, values = FALSE, as.points = TRUE)
                 },
                 thickening = { 
                   # There is probably a faster way using a radius and angle from each observations. Right now, rasterizing the buffers and sampling from the raster seems much faster than sampling within the buffers using sf (commented version)
                   #backgr<-obs |> 
                   #  st_buffer(dist = width_buffer, nQuadSegs = 10) |> 
                   #  st_sample(size = rep(ceiling(n / nrow(obs)),nrow(obs)), by_polygon = FALSE) |> 
                   #  st_as_sf()
                   #backgr[sample(1:nrow(backgr),n),]
                   terra::spatSample(
                     rasterize(st_buffer(obs, dist = width_buffer, nQuadSegs = 10), rast(predictors[[1]]), fun = sum),
                     size = n, 
                     method = "weights", 
                     replace = TRUE, 
                     values = FALSE, 
                     as.points = TRUE
                   )
                 }
  )
  backgr <- backgr[,-1] # temporary fix for https://github.com/rspatial/terra/issues/1275
  backgr <- st_as_sf(backgr) |> 
    st_coordinates() |>
    data.frame(id = 1:nrow(backgr), scientific_name = obs$scientific_name[1], lon = _) |>
    setNames(c("id","scientific_name","lon","lat"))
  backgr
  
}

calculate_dist_buffer <- function(obs, n = 1000) {
  # uses the first 1000 points (randomly sampled) to create buffers and distances
  if (nrow(obs) > n) {
    nb_buffer_point <- n
  } else {
    nb_buffer_point <- nrow(obs) - 1
  }
  
  sample_locations <- obs[sample(c(1:nrow(obs)),
                                 size = nb_buffer_point, replace = FALSE), ]
  #Uses the 95% quantile of the minimum distance between each point
  distance <- raster::pointDistance(sample_locations, lonlat = FALSE)
  mindist <- c()
  for (q in 1:ncol(distance)) {
    distance_zero <- distance[which(distance[, q] > 0), q]
    mindist <- c(mindist, min(distance_zero))
  }
  dist_buffer <- 2 * stats::quantile(mindist, 0.95)
  return(dist_buffer)
}
