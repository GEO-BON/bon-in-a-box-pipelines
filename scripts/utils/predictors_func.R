#' @name load_predictors
#' 
#' @param from_tif, string, path to the folder containing the initial raster layers
#' @param subsetLayers, a vector, containing the name of layers to select. If NULL, all layers in dir.pred selected by default.
#' @param removeCollinear, boolean. If TRUE, an analysis of collinearity is performed. 
#' @param method, The correlation method to be used:"vif.cor", "vif.step", "pearson", "spearman"
#' or "kendall". "vif.cor" and "vif.step" use the Variance Inflation factor and the pearson correlation, more details
#' here https://www.rdocumentation.org/packages/usdm/versions/1.1-18/topics/vif. If your variables are skewed or have outliers 
#' (e.g. when working with precipitation variables) you should favour the Spearman or Kendall methods.
#' @param method.cor.vif, the correlation method to be used with "vif.cor" method. "pearson", "spearman"
#' or "kendall".
#' @param proj, a string , proj if raster layers has to be reprojected
#' @param mask, a polygon to crop the raster
#' @param sample, boolean value. If TRUE, sample a number of points equal to nb.points before evaluating collinearity
#' @param nb.points, a numeric value. Only used if sample.points = TRUE. The number of sampled points from the raster.
#' @param cutoff.cor, a numeric value corresponding to the maximum threshold of linear correlation (for "vif.cor", "pearson", "spearman").
#' @param cutoff.vif, a numeric value corresponding to the maximum threshold of VIF (only used for method "vif.step").
#' @param export, boolean value. If TRUE, the list of selected variables and the correlation matrix will be saved in nonCollinearDir.
#' @param loadNonCollinear, boolean, if TRUE, a list of non-collinear layers is used to subset the raster stack (loaded from nonCollinearDir)
#' @param nonCollinearDir, string, path to the folder export or impot the list of non-collinear layers (if loadNonCollinear = T)
#' @return a raster stack of variables not intercorrelated
#' @import terra raster
#' @export 
load_predictors <- function(source = "from_cube",
                            cube_args = list(stac_path = "http://io.biodiversite-quebec.ca/stac/",
                                             limit = 5000, 
                                             collections = c("chelsa-clim"),     
                                             t0 = "1981-01-01",
                                             t1 = "1981-01-01",
                                             spatial.res = 1000, # in meters
                                             temporal.res = "P1Y",
                                             aggregation = "mean",
                                             resampling = "near",
                                             buffer.box = NULL),
                            predictors_dir = NULL,
                            subset_layers = NULL,
                            remove_collinear = T,
                            method = "vif.cor",
                            method_cor_vif = NULL,
                            new_proj = NULL,
                            mask = NULL,
                            sample = TRUE,
                            nb_points = 5000,
                            cutoff_cor = 0.7,
                            cutoff_vif = 3,
                            export = TRUE,
                            ouput_dir = NULL,
                            as.list = T) {
  
  
  if (!method %in% c("none", "vif.cor", "vif.step", "pearson", "spearman", "kendall")) {
    stop("method must be vif.cor, vif.step, pearson, spearman, or kendall")
  }
  
  if (method %in% c("vif.cor", "pearson", "spearman", "kendall") && is.null(cutoff_cor)) {
    cutoff_cor <- 0.8
  }
  
  if (source == "from_tif") {
    
    if (!is.null(subset_layers)) {
      files <- sprintf("%s%s.tif", predictors_dir, subset_layers) 
    } else {
      files <- list.files(predictors_dir, pattern = "*.tif$", full.names = TRUE)
      
    }

    if (length(files) == 0) {
      stop(sprintf("No tif files found in the directory %s", predictors_dir))
      
    }
    
    #Load rasterss
    all_predictors <- lapply(files,
                             terra::rast)
    all_predictors <- terra::rast(all_predictors)
    
    if (!is.null(mask)) {
      all_predictors <- fast_crop(all_predictors, mask)
    }
    
    if (!is.null(new_proj)) {
      all_predictors <- terra::project(all_predictors, new_proj)
      
    }
  } else {
    if (inherits(mask, "bbox")) {
     
       bbox <- mask
       mask <- mask %>%
       sf::st_as_sfc() 

       } else {
  
        bbox <- shp_to_bbox(mask)
       }
 
     cube_args_c <- append(cube_args, list(layers = subset_layers, 
                                          srs.cube = new_proj, use.obs = F, 
                                          bbox = bbox))
    print(cube_args_c)
    all_predictors <- do.call(load_cube, cube_args_c)

    all_predictors <- gdalcubes::filter_geom(all_predictors,  sf::st_geometry(sf::st_as_sf(mask), srs = new_proj))
  }
  nc_names <- names(all_predictors)
  # Selection of non-collinear predictors
  if (remove_collinear) {
    if (sample) {
      env_df <- sample_spatial_obj(all_predictors, nb_points = nb_points)
    }
    
    nc_names <-detect_collinearity(env_df,
                                   method = method ,
                                   method_cor_vif = method_cor_vif,
                                   cutoff_cor = cutoff_cor,
                                   cutoff_vif = cutoff_vif,
                                   export = export,
                                   title_export = "Correlation plot of climatic and topographic variables.",
                                   path = ouput_dir) 
    
  }                               
  
  
  if (as.list) {
    output <- nc_names
    
  } else {

    if (source == "from_tif") {
      output <- terra::subset(all_predictors, nc_names)
      
    } else {
      
      cube_args_nc <- append(cube_args, list(layers = nc_names, 
                                             srs.cube = new_proj, use.obs = F, 
                                             bbox = bbox))
      output <- do.call(load_cube, cube_args_nc)
      output <- gdalcubes::filter_geom(output,  sf::st_geometry(sf::st_as_sf(mask), srs = new_proj))
      
      
    }
  }
  return(output)
}

extract_gdal_cube <- function(cube, n_sample = 5000, simplify = T) {
  
  x <- gdalcubes::dimension_values(cube)$x
  y <- gdalcubes::dimension_values(cube)$y
  
  all_points <- expand.grid(x,y) %>% setNames(c("x", "y"))
  
  if (n_sample >= nrow(all_points)) {
    value_points <- gdalcubes::extract_geom(cube, sf::st_as_sf(all_points, coords = c("x", "y"),
                                               crs = gdalcubes::srs(cube))) 
  } else {
    sample_points <- all_points[sample(1:nrow(all_points), n_sample),]
    value_points <- gdalcubes::extract_geom(cube, sf::st_as_sf(sample_points, coords = c("x", "y"),
                                                               crs = gdalcubes::srs(cube))) 
  }
  
  if (simplify) {
    value_points <- value_points %>% dplyr::select(-FID, -time)
  }
  value_points
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


#' @name sample_spatial_obj
#' @param predictors, a raster, either from raster or terra format
#' @param method, The correlation method to be used:"vif.cor", "vif.step", "pearson", "spearman"
#' or "kendall". "vif.cor" and "vif.step" use the Variance Inflation factor and the pearson correlation, more details
#' here https://www.rdocumentation.org/packages/usdm/versions/1.1-18/topics/vif. If your variables are skewed or have outliers 
#' (e.g. when working with precipitation variables) you should favour the Spearman or Kendall methods.
#' @param method.cor.vif, the correlation method to be used with "vif.cor" method. "pearson", "spearman"
#' or "kendall".
#' @param mask, a 
#' @param sample, boolean value. If TRUE, sample a number of points equal to nb.points before evaluating collinearity
#' @param nb.points, a numeric value. Only used if sample.points = TRUE. The number of sampled points from the raster.
#' @param cutoff.cor, a numeric value corresponding to the maximum threshold of linear correlation (for "vif.cor", "pearson", "spearman").
#' @param cutoff.vif, a numeric value corresponding to the maximum threshold of VIF (only used for method "vif.step").
#' @param export, boolean value. If TRUE, the list of selected variables and the correlation matrix will be saved.
#' @param title_export, a string. If export is TRUE, title of the correlation matrix.
#' @param path, a string. If export is TRUE, path to save the corrrelation matrix and list of uncorrelated variables.
#' @return a raster stack of variables not intercorrelated
#' @import terra raster virtualspecies

sample_spatial_obj <- function(obj_to_sample, nb_points = 5000) {
  names_layers <- names(obj_to_sample)

  if(inherits(obj_to_sample, "RasterStack")) {
    
    if (raster::ncell(obj_to_sample) > nb_points) {
      env_df <- raster::sampleRandom(obj_to_sample, size = nb_points, na.rm = TRUE)
      
    } else {
      env_df <- raster::getValues(obj_to_sample) 
    }

  } else if (inherits(obj_to_sample, "SpatRaster")) {
    if (terra::ncell(obj_to_sample) > nb_points) {
      env_df <- terra::spatSample(obj_to_sample, size = nb_points, na.rm = TRUE,
                                  method="random", replace=FALSE) %>% as.matrix()
      
    } else {
      env_df <- terra::values(obj_to_sample, matrix = T)
      
    }
    
  } else if (inherits(obj_to_sample, "data.frame")) {
    if (nrow(env_df) > nb_points) {
      obj_to_sample <- obj_to_sample[sample(1:nrow(obj_to_sample), nb_points), ]
    
  } else {
    env_df <- obj_to_sample
  }
  } else if (inherits(obj_to_sample, "cube")) {
    env_df <- extract_gdal_cube(obj_to_sample, n_sample = nb_points, simplify = T)
  }
    env_df <- setNames(data.frame(env_df), names_layers)
   message(paste0(nrow(env_df), " points randomly selected (excluding NA's)."))
  return(env_df)
}

detect_collinearity <- function(env_df,
                                method = "vif.cor",
                                method_cor_vif = NULL,
                                cutoff_cor = 0.7,
                                cutoff_vif = 10,
                                export = FALSE,
                                title_export = "",
                                path = NULL) {
  

  #remove NA's
  comp <-  complete.cases(env_df)
  env_df <- env_df[comp, ]
  
  if (method == "vif.cor") {
    
    excluded <- vif.cor(env_df, th = cutoff_cor,
                        method = method_cor_vif,
                        maxobservations = nrow(env_df))
    retained <- setdiff(names(env_df), excluded)
  }
  
  if (method == "vif.step") {
    
    excluded <- vif.step(env_df, th = cutoff_vif, maxobservations = nrow(env_df))
    retained <- setdiff(names(env_df), excluded)
  }
  
  
  if(method %in% c("pearson", "spearman", "kendall")) {

        # Correlation based on Pearson
    cor.matrix <- 1 - abs(stats::cor(env_df, method = method))
    
    # Transforming the correlation matrix into an ascendent hierarchical classification
    dist.matrix <- stats::as.dist(cor.matrix)
    ahc <- stats::hclust(dist.matrix, method = "complete")
    groups <- stats::cutree(ahc, h = 1 - cutoff_cor)
    if(length(groups) == max(groups)){ 
      retained <- names(env_df)
    } else { 
      retained <- NULL
      for (i in 1:max(groups))
      {
        retained <- c(retained, sample(names(groups[groups == i]), 1))
      }
    } 
    excluded <- setdiff(names(env_df), retained)

  }

  nb_excluded <- length(excluded)
  
  # If some variables excluded
  if (length(nb_excluded) > 0) {
    
    if (method %in% c("vif.cor", "vif.step" )) {
      message(sprintf("%s variables excluded with VIF threshold = %s",
                      nb_excluded, cutoff_vif))
    } else {
      message(sprintf("%s variables excluded with method %s and cutoff_cor = %s", 
                      nb_excluded, method, cutoff_cor))
      
    }
    
    # If no variables excluded
  } else {  
    if (method %in% c("vif.cor", "vif.step" )) {
      message(sprintf("No variables excluded with VIF threshold = %s",
                      cutoff_vif))
    } else {
      message(sprintf("No variables excluded with method %s and cutoff_cor = %s", 
                      method, cutoff_cor))
      
    }
  }
  
  
  if (export) {
    if (is.null(path)) {
      stop("You must provide a path to export the correlation matrix.")
    }
    if (method == "vif.cor") {
      method <- method_cor_vif
    } else if (method == "vif.step") {
      method <- "pearson"
    }
    cm <- cor(env_df, method = method, use =  "complete.obs")
    
    png(file = paste(path, 'cm_plot.png', sep = "/"))
    corrplot::corrplot(cm, tl.col = "black",
             title = title_export)
    dev.off()
    message("Correlation plot saved.")
    
    write.table(retained, file = paste(path, "retained_predictor.csv", sep = "/"), row.names = F, col.names = F, sep = ";")
    message("List of uncorrelated variables saved.")
  }
  return(retained)
  
}


# from usdm package (https://github.com/cran/usdm/blob/master/R/vif.R)
maxCor <- function(k) {
  k <- abs(k)
  n <- nrow(k)
  for (i in 1:n) k[i:n, i] <- NA
  w <- which.max(k)
  c(rownames(k)[((w %/% nrow(k)) + 1)], colnames(k)[w %% nrow(k)])
}

# from usdm package (https://github.com/cran/usdm/blob/master/R/vif.R)
vif2 <- function(y, w) {
  z <- rep(NA, length(w))
  names(z) <- colnames(y)[w]
  for (i in 1:length(w)) {
    z[i] <- 1 / (1 - summary(lm(as.formula(paste(colnames(y)[w[i]], "~.", sep = "")), data = y))$r.squared)
  }
  return(z)
}

# from usdm package (https://github.com/cran/usdm/blob/master/R/vif.R)
vif <- function(y) {
  z <- rep(NA, ncol(y))
  names(z) <- colnames(y)
  for (i in 1:ncol(y)) {
    z[i] <- 1 / (1 - summary(lm(y[, i] ~ ., data = y[-i]))$r.squared)
  }
  return(z)
}

# adapted and corrected from usdm package (https://github.com/cran/usdm/blob/master/R/vif.R)

vif.cor <- function(x, th = 0.9, method = "pearson", maxobservations = 5000) {
  
  if (is.null(method) || !method %in% c("pearson", "kendall", "spearman")) method <- "pearson"
  x <- as.data.frame(x)
  
  LOOP <- TRUE
  if (nrow(x) > maxobservations) x <- x[sample(1:nrow(x), maxobservations), ]
  x <- na.omit(x)
  exc <- c()
  while (LOOP) {
    xcor <- abs(cor(x, method = method))
    mx <- maxCor(xcor)
    if (xcor[mx[1], mx[2]] >= th) {
      w1 <- which(colnames(xcor) == mx[1])
      w2 <- which(rownames(xcor) == mx[2])
      v <- vif2(x, c(w1, w2))
      ex <- mx[which.max(v[mx])]
      exc <- c(exc, ex)
      x <- as.data.frame(x[, -which(colnames(x) == ex)])
      if (ncol(x) == 1) {
        LOOP <- FALSE
      }
    } else {
      LOOP <- FALSE
    }
  }
  exc
}

# adapted and corrected from usdm package (https://github.com/cran/usdm/blob/master/R/vif.R)
vif.step <- function(x, th = 10, maxobservations = 5000) {
  LOOP <- TRUE
  x <- as.data.frame(x)
  x <- na.omit(x)
  if (nrow(x) > maxobservations) x <- x[sample(1:nrow(x), maxobservations), ]
  exc <- c()
  while (LOOP) {
    v <- vif(x)
    if (v[which.max(v)] >= th) {
      ex <- names(v[which.max(v)])
      exc <- c(exc, ex)
      x <- x[, -which(colnames(x) == ex)]
      if (ncol(x) == 1) {
        LOOP <- FALSE
      }
    } else {
      LOOP <- FALSE
    }
  }
  
  exc
}
