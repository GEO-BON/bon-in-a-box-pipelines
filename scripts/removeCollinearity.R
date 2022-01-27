#' @param predictors, a raster, either from raster or terra format
#' @param mask, a shape, either from raster or terra format
#' @return the predictors raster cropped and masked by mask, in terra format
#' @importFrom terra crop
#' @importFrom terra rast
#' @importFrom terra vect
#' @importFrom terra mask
#' 
crop_model <- function(predictors,
                       mask) {
  
  # convert into terra raster
  if (!class(predictors) %in% c("SpatRaster")) {
    predictors <- terra::rast(predictors)
  }
  
  # convert into a SpatVector
  
  if (!class(predictors) %in% c("SpatVectors")) {
    mask <- terra::vect(mask)
  }
  
  predictors <- terra::crop(predictors, mask)
  predictors <- terra::mask(predictors, mask, touches = FALSE)
  
  return(predictors)
}


#' @title Remove collinear variables
#' 
#' @name removeCollinearity
#' 
#' @param predictors, a raster, either from raster or terra format
#' @param method, The correlation method to be used:"vif.cor", "vif.step", "pearson", "spearman"
#' or "kendall". "vif.cor" and "vif.step" use the Variance Inflation factor and the pearson correlation, more details
#' here https://www.rdocumentation.org/packages/usdm/versions/1.1-18/topics/vif. If your variables are skewed or have outliers 
#' (e.g. when working with precipitation variables) you should favour the Spearman or Kendall methods.
#' @param method.cor.vif, the correlation method to be used with "vif.cor" method. "pearson", "spearman"
#' or "kendall".
#' @param sample, boolean value. If TRUE, sample a number of points equal to nb.points before evaluating collinearity
#' @param nb.points, a numeric value. Only used if sample.points = TRUE. The number of sampled points from the raster.
#' @param cutoff.cor, a numeric value corresponding to the maximum threshold of linear correlation (for "vif.cor", "pearson", "spearman").
#' @param cutoff.vif, a numeric value corresponding to the maximum threshold of VIF (only used for method "vif.step").
#' @param export, boolean value. If TRUE, the list of selected variables and the correlation matrix will be saved.
#' @param title_export, a string. If export is TRUE, title of the correlation matrix.
#' @param path, a string. If export is TRUE, path to save the corrrelation matrix and list of uncorrelated variables.
#' @return a raster stack of variables not intercorrelated
#' @import terra, raster, virtualspecies
#' @export 


removeCollinearity <- function(predictors,
                             method = "vif.cor",
                             method.cor.vif = NULL,
                             buffer = NULL,
                             sample = FALSE,
                             nb.points = 5000,
                             cutoff.cor = 0.7,
                            cutoff.vif = 10,
                            export = FALSE,
                            title_export = "",
                            path = NULL) {
  
  if (!method %in% c("none", "vif.cor", "vif.step", "pearson", "spearman", "kendall")) {
    stop("method must be vif.cor, vif.step, pearson, spearman, or kendall")
  }
  
  if (method %in% c("vif.cor", "pearson", "spearman", "kendall") && is.null(cutoff.cor)) {
    cutoff.cor <- 0.8
  }
  
  if (!class(predictors) %in% c("RasterBrick", "RasterStack", "SpatRaster")) {
    stop("predictors must be a RasterBrick, a RasterStack or a SpatRaster object")
  }
  if (!is.null(buffer) & class(buffer) %in% c("RasterBrick", "RasterStack")) {
    predictors <- crop_model(predictors, buffer)
  }
  
  if (!class(predictors) %in% c("RasterBrick", "RasterStack")) {
    names.i <- names(predictors)
    predictors <- raster::stack(predictors) 
    names(predictors) <-   names.i # if not, names are sometimes modified by the functiom raster::stack
    }
  

  message(paste0("Removing collinearity in predictors with method ", method, "..."))
  
  # By default, all the initial variables are retained.
  retained <- names(predictors)
  
  
  if (sample == FALSE) {
    maxobservations <- raster::ncell(predictors) # by default, maxobservations of vifcor function = 5000.
  } else {
    maxobservations <- nb.points
  }
  message(paste0(maxobservations, " points used to calculate collinearity."))
  
  
  if (method == "vif.cor") {

    excluded <- vif.cor(predictors, th = cutoff.cor,
                        method = method.cor.vif,
                        maxobservations = maxobservations)
    retained <- setdiff(names(predictors), excluded)
  }
  
  if (method == "vif.step") {

    excluded <- vif.step(predictors, th = cutoff.vif, maxobservations = maxobservations)
    retained <- setdiff(names(predictors), excluded)
  }
  
  
  if(method %in% c("pearson", "spearman", "kendall")) {
    retained <- virtualspecies::removeCollinearity(predictors,  method = method,
                                                   multicollinearity.cutoff = cutoff.cor, 
                                                   plot = F, select.variables = T, 
                                                   sample.points = sample,
                                                   nb.points = maxobservations)
    
  }
  
  nb_excluded <- nlayers(predictors) - length(retained)
  
  # If some variables excluded
  if (length(nb_excluded) > 0) {
    
    final_predictors <- raster::subset(predictors, retained)
    if (method %in% c("vif.step")) {
      message(paste(paste(nb_excluded, collapse = ","),
                    "variables excluded with VIF threshold = ", cutoff.vif))
    } else {
      message(paste(paste(nb_excluded, collapse = ","),
                    "variables excluded with correlation threshold = ", cutoff.cor))
      
    }

  # If no variables excluded
  } else {  
    final_vars <- predictors
    if (method %in% c("vif.step")) {
      message(paste("No variables excluded with VIF threshold = ", cutoff.vif))
    } else {
      message(paste("No variables excluded with correlation threshold = ", cutoff.cor))
    }
  }
  
  
  if (export) {
    if (is.null(path)) {
      stop("You must provide a path to export the correlation matrix.")
    }
    
    message("Calculating correlation matrix for export")
    cm <- correlation(predictors, plot = FALSE)
    png(file = paste(path, 'cm_plot.png', sep = "/"))
    corrplot(cm, tl.col = "black",
             title = title_export)
    dev.off()
    message("Correlation plot saved.")
    
    write.table(retained, file = paste(path, "retained_predictor.csv", sep = "/"), row.names = F, col.names = F, sep = ";")
    message("List of uncorrelated variables saved.")
  }
  
  
  return(final_predictors)
  
}





# from usdm package (https://github.com/cran/usdm/blob/master/R/vif.R)

maxCor <- function(k){
  k <- abs(k)
  n <- nrow(k)
  for (i in 1:n) k[i:n,i] <- NA
  w <- which.max(k)
  c(rownames(k)[((w%/%nrow(k))+1)],colnames(k)[w%%nrow(k)])
}

# from usdm package (https://github.com/cran/usdm/blob/master/R/vif.R)
vif2 <- function(y,w) {
  z<-rep(NA,length(w))
  names(z) <- colnames(y)[w]
  for (i in 1:length(w)) {
    z[i] <-  1/(1-summary(lm(as.formula(paste(colnames(y)[w[i]],"~.",sep='')),data=y))$r.squared)
  }
  return(z)
}

# from usdm package (https://github.com/cran/usdm/blob/master/R/vif.R)
vif <- function(y) {
  z<-rep(NA,ncol(y))
  names(z) <- colnames(y)
  for (i in 1:ncol(y)) {
    z[i] <-  1/(1-summary(lm(y[,i]~.,data=y[-i]))$r.squared)
  }
  return(z)
}

# adapted and corrected from usdm package (https://github.com/cran/usdm/blob/master/R/vif.R)

vif.cor <- function(x, th = 0.9, method ='pearson', maxobservations=5000) {
  if (nlayers(x) == 1) stop("The Raster object should have at least two layers")
  if (missing(method) || !method %in% c('pearson','kendall','spearman')) method <- 'pearson'
  LOOP <- TRUE
  x <- as.data.frame(x)
  if(nrow(x) > maxobservations) x <- x[sample(1:nrow(x),maxobservations),]
  x <- na.omit(x)
  exc <- c()
  while (LOOP) {
    xcor <- abs(cor(x, method = method))
    mx <- maxCor(xcor)
    if (xcor[mx[1],mx[2]] >= th) {
      w1 <- which(colnames(xcor) == mx[1])
      w2 <- which(rownames(xcor) == mx[2])
      v <- vif2(x,c(w1,w2))
      ex <- mx[which.max(v[mx])]
      exc <- c(exc,ex)
      x <- as.data.frame(x[,-which(colnames(x) == ex)])
      if (ncol(x) == 1) {
        LOOP <- FALSE
      }
    } else LOOP <- FALSE
  }
exc

}

# adapted and corrected from usdm package (https://github.com/cran/usdm/blob/master/R/vif.R)
vif.step <- function(x, th = 10, maxobservations = 5000) {
  if (nlayers(x) == 1) stop("The Raster object should have at least two layers!")
  LOOP <- TRUE
  x <- as.data.frame(x)
  x <- na.omit(x)
  if(nrow(x) > maxobservations) x <- x[sample(1:nrow(x),maxobservations),]
  exc <- c()
  while (LOOP) {
    v <- vif(x)
    if (v[which.max(v)] >= th) {
      ex <- names(v[which.max(v)])
      exc <- c(exc,ex)
      x <- x[,-which(colnames(x) == ex)]
      if (ncol(x) == 1) {
        LOOP <- FALSE
      }
      
    } else LOOP=FALSE
  }

  exc
}
#' @param predictors, a raster, either from raster or terra format
#' @param mask, a shape, either from raster or terra format
#' @return the predictors raster cropped and masked by mask, in terra format
#' @importFrom terra crop
#' @importFrom terra rast
#' @importFrom terra vect
#' @importFrom terra mask
#' 
crop_model <- function(predictors,
                       mask) {
  
  # convert into terra raster
  if (!class(predictors) %in% c("SpatRaster")) {
    predictors <- terra::rast(predictors)
  }
  
  # convert into a SpatVector
  
  if (!class(predictors) %in% c("SpatVectors")) {
    mask <- terra::vect(mask)
  }
  
  predictors <- terra::crop(predictors, mask)
  predictors <- terra::mask(predictors, mask, touches = FALSE)
  
  return(predictors)
}


#' @title Remove collinear variables
#' 
#' @name removeCollinearity
#' 
#' @param predictors, a raster, either from raster or terra format
#' @param method, The correlation method to be used:"vif.cor", "vif.step", "pearson", "spearman"
#' or "kendall". "vif.cor" and "vif.step" use the Variance Inflation factor and the pearson correlation, more details
#' here https://www.rdocumentation.org/packages/usdm/versions/1.1-18/topics/vif. If your variables are skewed or have outliers 
#' (e.g. when working with precipitation variables) you should favour the Spearman or Kendall methods.
#' @param method.cor.vif, the correlation method to be used with "vif.cor" method. "pearson", "spearman"
#' or "kendall".
#' @param sample, boolean value. If TRUE, sample a number of points equal to nb.points before evaluating collinearity
#' @param nb.points, a numeric value. Only used if sample.points = TRUE. The number of sampled points from the raster.
#' @param cutoff.cor, a numeric value corresponding to the maximum threshold of linear correlation (for "vif.cor", "pearson", "spearman").
#' @param cutoff.vif, a numeric value corresponding to the maximum threshold of VIF (only used for method "vif.step").
#' @param export, boolean value. If TRUE, the list of selected variables and the correlation matrix will be saved.
#' @param title_export, a string. If export is TRUE, title of the correlation matrix.
#' @param path, a string. If export is TRUE, path to save the corrrelation matrix and list of uncorrelated variables.
#' @return a raster stack of variables not intercorrelated
#' @import terra, raster, virtualspecies
#' @export 


removeCollinearity <- function(predictors,
                             method = "vif.cor",
                             method.cor.vif = NULL,
                             buffer = NULL,
                             sample = FALSE,
                             nb.points = 5000,
                             cutoff.cor = 0.7,
                            cutoff.vif = 10,
                            export = FALSE,
                            title_export = "",
                            path = NULL) {
  
  if (!method %in% c("none", "vif.cor", "vif.step", "pearson", "spearman", "kendall")) {
    stop("method must be vif.cor, vif.step, pearson, spearman, or kendall")
  }
  
  if (method %in% c("vif.cor", "pearson", "spearman", "kendall") && is.null(cutoff.cor)) {
    cutoff.cor <- 0.8
  }
  
  if (!class(predictors) %in% c("RasterBrick", "RasterStack", "SpatRaster")) {
    stop("predictors must be a RasterBrick, a RasterStack or a SpatRaster object")
  }
  if (!is.null(buffer) & class(buffer) %in% c("RasterBrick", "RasterStack")) {
    predictors <- crop_model(predictors, buffer)
  }
  
  if (!class(predictors) %in% c("RasterBrick", "RasterStack")) {
    names.i <- names(predictors)
    predictors <- raster::stack(predictors) 
    names(predictors) <-   names.i # if not, names are sometimes modified by the functiom raster::stack
    }
  

  message(paste0("Removing collinearity in predictors with method ", method, "..."))
  
  # By default, all the initial variables are retained.
  retained <- names(predictors)
  
  
  if (sample == FALSE) {
    maxobservations <- raster::ncell(predictors) # by default, maxobservations of vifcor function = 5000.
  } else {
    maxobservations <- nb.points
  }
  message(paste0(maxobservations, " points used to calculate collinearity."))
  
  
  if (method == "vif.cor") {

    excluded <- vif.cor(predictors, th = cutoff.cor,
                        method = method.cor.vif,
                        maxobservations = maxobservations)
    retained <- setdiff(names(predictors), excluded)
  }
  
  if (method == "vif.step") {

    excluded <- vif.step(predictors, th = cutoff.vif, maxobservations = maxobservations)
    retained <- setdiff(names(predictors), excluded)
  }
  
  
  if(method %in% c("pearson", "spearman", "kendall")) {
    retained <- virtualspecies::removeCollinearity(predictors,  method = method,
                                                   multicollinearity.cutoff = cutoff.cor, 
                                                   plot = F, select.variables = T, 
                                                   sample.points = sample,
                                                   nb.points = maxobservations)
    
  }
  
  nb_excluded <- nlayers(predictors) - length(retained)
  
  # If some variables excluded
  if (length(nb_excluded) > 0) {
    
    final_predictors <- raster::subset(predictors, retained)
    if (method %in% c("vif.step")) {
      message(paste(paste(nb_excluded, collapse = ","),
                    "variables excluded with VIF threshold = ", cutoff.vif))
    } else {
      message(paste(paste(nb_excluded, collapse = ","),
                    "variables excluded with correlation threshold = ", cutoff.cor))
      
    }

  # If no variables excluded
  } else {  
    final_vars <- predictors
    if (method %in% c("vif.step")) {
      message(paste("No variables excluded with VIF threshold = ", cutoff.vif))
    } else {
      message(paste("No variables excluded with correlation threshold = ", cutoff.cor))
    }
  }
  
  
  if (export) {
    if (is.null(path)) {
      stop("You must provide a path to export the correlation matrix.")
    }
    
    message("Calculating correlation matrix for export")
    cm <- correlation(predictors, plot = FALSE)
    png(file = paste(path, 'cm_plot.png', sep = "/"))
    corrplot(cm, tl.col = "black",
             title = title_export)
    dev.off()
    message("Correlation plot saved.")
    
    write.table(retained, file = paste(path, "retained_predictor.csv", sep = "/"), row.names = F, col.names = F, sep = ";")
    message("List of uncorrelated variables saved.")
  }
  
  
  return(final_predictors)
  
}





# from usdm package (https://github.com/cran/usdm/blob/master/R/vif.R)

maxCor <- function(k){
  k <- abs(k)
  n <- nrow(k)
  for (i in 1:n) k[i:n,i] <- NA
  w <- which.max(k)
  c(rownames(k)[((w%/%nrow(k))+1)],colnames(k)[w%%nrow(k)])
}

# from usdm package (https://github.com/cran/usdm/blob/master/R/vif.R)
vif2 <- function(y,w) {
  z<-rep(NA,length(w))
  names(z) <- colnames(y)[w]
  for (i in 1:length(w)) {
    z[i] <-  1/(1-summary(lm(as.formula(paste(colnames(y)[w[i]],"~.",sep='')),data=y))$r.squared)
  }
  return(z)
}

# from usdm package (https://github.com/cran/usdm/blob/master/R/vif.R)
vif <- function(y) {
  z<-rep(NA,ncol(y))
  names(z) <- colnames(y)
  for (i in 1:ncol(y)) {
    z[i] <-  1/(1-summary(lm(y[,i]~.,data=y[-i]))$r.squared)
  }
  return(z)
}

# adapted and corrected from usdm package (https://github.com/cran/usdm/blob/master/R/vif.R)

vif.cor <- function(x, th = 0.9, method ='pearson', maxobservations=5000) {
  if (nlayers(x) == 1) stop("The Raster object should have at least two layers")
  if (missing(method) || !method %in% c('pearson','kendall','spearman')) method <- 'pearson'
  LOOP <- TRUE
  x <- as.data.frame(x)
  if(nrow(x) > maxobservations) x <- x[sample(1:nrow(x),maxobservations),]
  x <- na.omit(x)
  exc <- c()
  while (LOOP) {
    xcor <- abs(cor(x, method = method))
    mx <- maxCor(xcor)
    if (xcor[mx[1],mx[2]] >= th) {
      w1 <- which(colnames(xcor) == mx[1])
      w2 <- which(rownames(xcor) == mx[2])
      v <- vif2(x,c(w1,w2))
      ex <- mx[which.max(v[mx])]
      exc <- c(exc,ex)
      x <- as.data.frame(x[,-which(colnames(x) == ex)])
      if (ncol(x) == 1) {
        LOOP <- FALSE
      }
    } else LOOP <- FALSE
  }
exc

}

# adapted and corrected from usdm package (https://github.com/cran/usdm/blob/master/R/vif.R)
vif.step <- function(x, th = 10, maxobservations = 5000) {
  if (nlayers(x) == 1) stop("The Raster object should have at least two layers!")
  LOOP <- TRUE
  x <- as.data.frame(x)
  x <- na.omit(x)
  if(nrow(x) > maxobservations) x <- x[sample(1:nrow(x),maxobservations),]
  exc <- c()
  while (LOOP) {
    v <- vif(x)
    if (v[which.max(v)] >= th) {
      ex <- names(v[which.max(v)])
      exc <- c(exc,ex)
      x <- x[,-which(colnames(x) == ex)]
      if (ncol(x) == 1) {
        LOOP <- FALSE
      }
      
    } else LOOP=FALSE
  }

  exc
}
