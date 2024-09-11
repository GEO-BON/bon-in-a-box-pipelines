#' @title Load predictor variables from tiff files or the stac catalogue
#' 
#' @name load_predictors
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
                            cube_args = list(stac_path = "http://stac.geobon.org/",
                                             limit = 5000, 
                                             collections = c("chelsa-clim"),     
                                             t0 = NULL,
                                             t1 = NULL,
                                             spatial.res = 1000, # in meters
                                             temporal.res = "P1Y",
                                             aggregation = "mean",
                                             resampling = "near"),
                            predictors_dir = NULL,
                            subset_layers = NULL,
                            variables = NULL,
                            ids = NULL,
                            remove_collinear = T,
                            method = "vif.cor",
                            method_cor_vif = NULL,
                            proj = NULL,
                            bbox = NULL,
                            mask = NULL,
                            sample = TRUE,
                            nb_points = 5000,
                            cutoff_cor = 0.7,
                            cutoff_vif = 3,
                            export = TRUE,
                            ouput_dir = NULL,
                            as_list = T) {
  
  
  if (!method %in% c("none", "vif.cor", "vif.step", "pearson", "spearman", "kendall")) {
    stop("method must be vif.cor, vif.step, pearson, spearman, or kendall")
  }
  
  if (method %in% c("vif.cor", "pearson", "spearman", "kendall") && is.null(cutoff_cor)) {
    cutoff_cor <- 0.8
  }
  
  if (source == "from_tif") {
    
    if (!is.null(subset_layers)) {
      files <- sprintf("%s/%s.tif", predictors_dir, subset_layers) 
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
    
    if (!is.null(proj)) {
      all_predictors <- terra::project(all_predictors, proj)
      
    }
    
  } else {


    cube_args_c <- append(cube_args, list(layers = subset_layers, 
                                          srs.cube = proj, 
                                          bbox = bbox,
                                          variable = variables,
                                          ids = ids))
    
    all_predictors <- do.call(stacatalogue::load_cube, cube_args_c)

     if(!is.null(mask)) {
        
        all_predictors <- gdalcubes::filter_geom(all_predictors,  sf::st_geometry(mask))
        
      }
    
 }
  
  nc_names <- names(all_predictors)
  
  # Selection of non-collinear predictors
  if (remove_collinear && length(nc_names) >1) {
    if (sample) {
      
      env_df <- sample_spatial_obj(all_predictors, nb_points = nb_points)
      
    }
    
    nc_names <-detect_collinearity(env_df,
                                   method = method ,
                                   method_cor_vif = method_cor_vif,
                                   cutoff_cor = cutoff_cor,
                                   cutoff_vif = cutoff_vif,
                                   export = export,
                                   title_export = "Correlation plot of environmental variables.",
                                   path = ouput_dir) 
    
  }                               
  
  
  if (as_list) {
    output <- nc_names
    
  } else {
    
    if (source == "from_tif") {
      output <- terra::subset(all_predictors, nc_names)
      
    } else {
      
      cube_args_nc <- append(cube_args, list(layers = nc_names, 
                                             srs.cube = proj,
                                             bbox = bbox))
      output <- do.call(stacatalogue::load_cube, cube_args_nc)
      #
      
      if(!is.null(mask)) {
        
      
     output <- gdalcubes::filter_geom(cube,  sf::st_geometry(sf::st_as_sf(mask)), srs=proj)
        
    
        
      }
    #  output <- cube_to_raster(output, format = "terra")
      
    }
  }
  return(output)
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
