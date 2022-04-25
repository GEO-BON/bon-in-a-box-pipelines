#' @name create_background
#' @param obs data frame, containing the coordinates to reproject
#' @param predictors, raster
#' @param lon string, name of the longitude column (same projection as predictor raster)
#' @param lat string, name of the latitude column (same projection as predictor raster)
#' @param proj character, initial projection of the xy coordinates
#' @return spatial points
#' @export

create_background <- function(
  species,
  study_extent,
  resolution,
  mask = NULL,
  method = "random",
  n = 10000,  
  obs = NULL,
  density_bias = NULL,
  dist_buffer = NULL) {
  
  study_extent_rast <- terra::rast(ext = raster::extent(study_extent), res = resolution)
  terra::values(study_extent_rast) <- 1
  study_extent_rast <- fast_crop(study_extent_rast, study_extent)
print(study_extent_rast)
  proj <- terra::crs(study_extent, proj = T)
print(proj)
  if (!is.null(mask)) study_extent_rast <- fast_crop(study_extent_rast, mask)

  if (method == "random") {
    
    # all the cells have the same probability to be selected
    
    message(sprintf("Selecting %i background point based on %s method.", n, method  ))
    
    backgr <- terra::spatSample(study_extent_rast,
                                size = n, method="random", replace=FALSE, na.rm=T,
                                xy=TRUE, as.points=FALSE, values=F)
     print(head(backgr))
  } else if (method == "inclusion_buffer") {
    obs <- obs %>% dplyr::select(lon, lat) %>% data.frame()
    # projecting observations coordinates
    obs_points <- project_coords(obs, "lon", "lat", proj)
    
    if (is.null(dist_buffer)) {
      
      message("Buffer distance not provided. Using the 95% quantile 
      of the minimum distance between each point.")
      dist_buffer <- calculate_dist_buffer(obs)
      message(sprintf("Buffer distance: %s (unit of projection)", dist_buffer))
      
    }
    
    # Creating the buffer
    
    buffer_shape <- rgeos::gBuffer(spgeom = obs_points,
                                   byid = FALSE, width = dist_buffer)
    # crops the predictors to that shape to rasterize
    study_extent_rast <- fast_crop(study_extent_rast,  buffer_shape)
    
    message(sprintf("Trying selecting %i background point based on %s method.", n ,method  ))
    backgr <- terra::spatSample(study_extent_rast,
                                size = n, method="random", replace=FALSE, na.rm=T,
                                xy=TRUE, as.points=FALSE, values=F)
    
    
    message(sprintf("%s selected", nrow(backgr)))
    
    
  } else if (method == "weighted_density") {
    
    study_extent_rast <- terra::app(study_extent_rast, fun=function(x){ x[!is.na(x)] <- 0; return(x)} )
    
    # densityRaster cells set to NA if NA in the layerSummarized
    density_bias <-terra::tapp(c(density_bias, study_extent_rast), index = c(1, 1), fun = sum, na.rm = F)
    
    message(sprintf("Selecting %i background point based on %s method.", n ,method  ))
    backgr <- terra::spatSample(density_bias,
                                size = n, method="weighted", replace=FALSE, na.rm=T,
                                xy=TRUE, as.points=FALSE, values=F)
    
  } 
  
  backgr <- dplyr::bind_cols(id = 1:nrow(backgr),
                      scientific_name = species,
                      backgr %>% data.frame()) %>%
    setNames(c("id", "scientific_name", "lon", "lat"))
  
  
  
  return(backgr)
}


calculate_dist_buffer <- function(obs, n = 1000) {
  #Uses the first 1000 points (randomly sampled) to create buffers and distances
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
