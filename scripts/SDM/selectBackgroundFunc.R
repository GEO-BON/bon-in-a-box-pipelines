

#' @title Create background points
#'
#' @name create_background
#' @param predictors spat raster, containing the predictor variables
#' @param mask, spat vector, mask to apply to the predictors.
#' @param method string, random, inclusion_buffer (thickening or biased), or raster (unweighted or weighted)
#' @param n integer, number of background points to select.
#' @param obs data.frame, containing the observations. Used with method == "thickening" or "inclusion_buffer"
#' @param width_buffer int, buffer width around observations. Used with method ==  "inclusion_buffer"
#' @param species string, species name.
#' @param raster SpatRaster, raster heatmap used for weighted or unweighted sampling, default NULL when not using those methods
#' @return spatial points
#' @export

create_background <- function(
    predictors,
    mask = NULL,
    method = "random",
    n = 10000,  
    obs = NULL,
    density_bias = NULL,
    width_buffer = NULL,
    raster = NULL) {
  
  proj <- terra::crs(predictors, proj = T)
  
  ## New method: If we use raster, we re-project our raster and add it as an additional layer
  if (grepl("raster", method)) {
    if (is.null(raster)) stop(paste("No raster included with method:", method))
    
    # Bilinear interpolation when projecting in this manner
    # Exclude 0s, since we don't want to sample areas with no sightings
    raster[raster <= 0] <- NA
    
    add(predictors) <- raster
    
  }
  
  if (!is.null(mask)) {
    predictors <- fast_crop(predictors, mask)
  }
  
  sum_na_layer <-  terra::tapp(predictors, index = rep(1, terra::nlyr(predictors)), fun = sum, na.rm = F)
  
  ncellr <- terra::global(!is.na(sum_na_layer), sum)
  
  if (ncellr < n) {
    message(
      "Number of background-points exceeds number of cell. ",
      ncellr,
      " background-points will be sampled"
    )
    backgr <- terra::as.data.frame(predictors, na.rm = TRUE, xy = TRUE) |> dplyr::select(x, y)
    
  } else {
    
    if (any(method == "random" | grepl("^unweighted", method))) {
      
      # all the cells have the same probability to be selected
      message(sprintf("Selecting %i background point based on %s method.", n, method  ))
      
      # Apparently this breaks if there are a lot of NA values.. using a different version for now
      if (0) {
        # This version has issues sampling rasters with a lot (or mostly) NA value cells
        backgr <- terra::spatSample(sum_na_layer,
                                    size = n,
                                    method="random", 
                                    replace = FALSE,
                                    na.rm = T,
                                    xy = TRUE, 
                                    as.points = FALSE, 
                                    values = F)
      }else{
        # cells only retrieves non-NA cells
        backgr <- sample(cells(sum_na_layer), n)
        backgr <- xyFromCell(sum_na_layer,backgr)
        
      }
    } else if (any(method == "thickening")) {
      
      message(sprintf("Selecting %i background point based on %s method.", n, method  ))
      
      obs_vec <- terra::vect(obs, geom = c("lon", "lat"), crs = crs(predictors))
      
      if (is.null(width_buffer)) {
        width_buffer <- mean(terra::distance(obs_vec))
      } else {
        width_buffer <- as.numeric(width_buffer)
      }
      buf <- terra::buffer(obs_vec, width_buffer, quadsegs = 10)
      buf_r <- !is.na(terra::rasterize(buf[1], sum_na_layer))
      for (i in 2:nrow(buf)) {
        buf_r <- buf_r + !is.na(terra::rasterize(buf[i], sum_na_layer))
      }
      buf_r <- terra::mask(buf_r, sum_na_layer)
      backgr <- terra::spatSample(buf_r,
                                  size = n,
                                  method = "weighted", 
                                  replace = FALSE,
                                  na.rm = T,
                                  xy = TRUE, 
                                  as.points = FALSE, 
                                  values = F)
      
    } else if (any(method == "biased")) {
      
      if (!is.null(mask)) density_bias <- fast_crop(density_bias, mask)
      
      backgr <- terra::spatSample(density_bias,
                                  size = n,
                                  method = "weighted", 
                                  replace = FALSE,
                                  na.rm = T,
                                  xy = TRUE, 
                                  as.points = FALSE, 
                                  values = F)
      
    } else if (method == "inclusion_buffer") {
      
      obs_vec <- terra::vect(obs, geom = c("lon", "lat"), crs = crs(predictors))
      
      if (is.null(dist_buffer)) {
        
        message("Buffer distance not provided. Using the 95% quantile 
      of the minimum distance between each point.")
        dist_buffer <- calculate_dist_buffer(obs |> dplyr::select(lon, lat))
        message(sprintf("Buffer distance: %s (unit of projection)", dist_buffer))
        
      }
      
      # Creating the buffer
      
      buffer_shape <- rgeos::gBuffer(spgeom = as(obs_vec, "Spatial"),
                                     byid = FALSE, width = dist_buffer)
      
      # crops the predictors to that shape to rasterize
      sum_na_layer <- fast_crop(sum_na_layer,  buffer_shape)
      
      message(sprintf("Trying selecting %i background point based on %s method.", n ,method  ))
      backgr <- terra::spatSample(sum_na_layer,
                                  size = n, 
                                  method="random",
                                  replace=FALSE,
                                  na.rm=T,
                                  xy=TRUE,
                                  as.points=FALSE, 
                                  values=F)
      
    } else if (grepl("^weighted", method)) {
      ## Replace sum_na_layer values with weighting from heatmap
      ## Assumes the last layer of predictors is the heatmap, and that it is counts!
      values(predictors[[dim(predictors)[3]]])[which(is.na(values(sum_na_layer)))] <- NA
      tgb_weights <- predictors[[dim(predictors)[3]]]
      tgb_weights <- tgb_weights/sum(values(tgb_weights), na.rm = T)
      
      # Sampling using density as probabilities
      backgr <- sample(cells(tgb_weights), n, prob = unlist(extract(tgb_weights, cells(tgb_weights))))
      backgr <- xyFromCell(tgb_weights, backgr)
      
    }
  }
  message(sprintf("%s selected", nrow(backgr)))
  
  species <- unique(obs$scientific_name) 
  backgr <- dplyr::bind_cols(id = 1:nrow(backgr),
                             scientific_name = species,
                             backgr |> data.frame()) |>
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
