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
                                  method="random", replace=FALSE) |> as.matrix()
      
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
