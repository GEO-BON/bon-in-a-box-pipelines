#' @name run_maxent
#' @param obs data frame, containing the coordinates to reproject
#' @param predictors, raster
#' @param lon string, name of the longitude column (same projection as predictor raster)
#' @param lat string, name of the latitude column (same projection as predictor raster)
#' @param proj character, initial projection of the xy coordinates
#' @return spatial points
#' @import ENMeval 
#' @export

run_maxent <- function(presence.bg, with_raster = F,
                        algorithm = "maxnet",
                        layers = c(),
                        factors = NULL,
                        predictors = NULL,
                        partition_type = "crossvalidation",
                        nfolds = 5,
                        orientation_block = "lat_lon",
                        fc = "L", rm =1,
                        parallel = T,
                        updateProgress = T,
                        parallelType = "doParallel"
) {
  
  presence <- presence.bg |> dplyr::filter(pa == 1) |> data.frame()
  background <- presence.bg |> dplyr::filter(pa == 0) |> data.frame()
  
  if (with_raster) {
    ENMmodel <- ENMeval::ENMevaluate(occs = presence[, c("lon", "lat")],
                            bg = background[, c("lon", "lat")], 
                            env = predictors, 
                            categoricals = factors,     
                            algorithm = algorithm,
                            partitions = partition_type, 
                            partition.settings = list(kfold = nfolds, orientation =  orientation_block),
                            tune.args = list(fc = fc, rm = rm),
                            parallel =  parallel,
                            updateProgress = updateProgress,
                            parallelType = )
    
    
  } else {
    layers <- c("lon", "lat", layers)
    ENMmodel <- ENMeval::ENMevaluate(occs = presence[,layers], 
                            bg = background[,layers],  
                            algorithm = algorithm,
                            categoricals = factors,
                            partitions = partition_type, 
                            partition.settings = list(kfold = nfolds, orientation =  orientation_block),
                            tune.args = list(fc = fc, rm = rm),
                            parallel =  parallel,
                            updateProgress = updateProgress,
                            parallelType = parallelType)
    
  }
  
  return(ENMmodel)
}


#' @name select_param
#' @param obs data frame, containing the coordinates to reproject
#' @param predictors, raster
#' @param lon string, name of the longitude column (same projection as predictor raster)
#' @param lat string, name of the latitude column (same projection as predictor raster)
#' @param proj character, initial projection of the xy coordinates
#' @return spatial points
#' @import dplyr 
#' @export
select_param <- function(res, method = "AIC", auc_min = 0, list = T) {
  
  res <- res |> 
        filter(auc.val.avg >= auc_min)
  if (nrow(res) == 0) {
    stop(sprintf("All models have AUC lower than %f", auc_min))
  }
  if (method == "AIC") {
    
    if (nrow(res |> dplyr::filter(delta.AICc <= 2) ) > 0) {
      res <- res |> dplyr::filter(delta.AICc <= 2) |> 
        dplyr::filter(or.10p.avg == min(or.10p.avg))  |> 
        dplyr::filter(auc.val.avg == max(auc.val.avg)) 
    } else {
      res <- res |> dplyr::filter(delta.AICc == min(delta.AICc))
      }
    
  } else if (method == "p10") {
      res <- res |> filter(or.10p.avg == min(or.10p.avg)) |> filter(auc.val.avg == max(auc.val.avg))
    
    } else if (method == "AUC") {
      res <- res |> filter(auc.val.avg == max(auc.val.avg))
    
    } 
 
  if (list) {
    param <- list(res$fc, as.double(as.character(res$rm)))
  } else {
    param <- sprintf("fc.%s_rm.%s", res$fc, res$rm)
  }
  return(param)
}

#' @name select_param
#' @param obs data frame, containing the coordinates to reproject
#' @param predictors, raster
#' @param lon string, name of the longitude column (same projection as predictor raster)
#' @param lat string, name of the latitude column (same projection as predictor raster)
#' @param proj character, initial projection of the xy coordinates
#' @return spatial points
#' @import dismo 
#' @export
response_plot <- function(mod, algorithm, param, type = "cloglog", path = NULL) {
       if (algorithm == "maxnet") {
           
r_plot <-   plot(mod@models[[param]], type = type)
        
      } else if (algorithm == "maxent.jar") {
    r_plot <- dismo::response(ENMeval::eval.models(mod)[[param]])
    }
     
     if(!is.null(path)) {
  jpeg(path, width = 900, height = 900)
  # 2. Create the plot
  if (algorithm == "maxnet") { 
    r_plot
  } else {
dismo::response(ENMeval::eval.models(mod)[[param]]) }
  # 3. Close the file
  dev.off()
     }
     return(r_plot)
      
}

#' @name select_param
#' @param obs data frame, containing the coordinates to reproject
#' @param predictors, raster
#' @param lon string, name of the longitude column (same projection as predictor raster)
#' @param lat string, name of the latitude column (same projection as predictor raster)
#' @param proj character, initial projection of the xy coordinates
#' @return spatial points
#' @import dplyr dismo
#' @export
predict_maxent_old <- function(mod, algorithm, param, predictors, type = "cloglog", mask = NULL) {
  if (inherits(predictors, "cube")) {
    predictors <- cube_to_raster(predictors, format = "raster")
  }
  if (!is.null(mask)) predictors <- fast_crop(predictors, mask)
  
  if (inherits(predictors, "spatRaster")) {
    predictors <- raster::stack(predictors)
  }

      if (raster::nlayers(mod@predictions) > 0 ) {
 
          pred_raster <- mod@predictions[[param]]
    } else {
      
      if (algorithm == "maxnet") {

      pred_raster <- dismo::predict(predictors, mod@models[[param]], clamp = T, type = type)
 
      
      } else if (algorithm == "maxent.jar") {
      pred_raster <- dismo::predict(mod@models[[param]], predictors,
       args = sprintf("outputformat=%s", type))
      
    }
    }
    return(pred_raster)
}

#' @name find_threshold
#' @param obs data frame, containing the coordinates to reproject
#' @param predictors, raster
#' @param lon string, name of the longitude column (same projection as predictor raster)
#' @param lat string, name of the latitude column (same projection as predictor raster)
#' @param proj character, initial projection of the xy coordinates
#' @return spatial points
#' @import dplyr dismo raster
#' @export

find_threshold <- function(sdm, occs, bg, type = "mtp"){
  
  if (type == "spse") {type <- "spec_sens"}
  #extract model estimated suitability for occurrence localities
  occs_vals <- raster::extract(sdm, occs)
  
  #extract model estimated suitability for background
  bg_vals <- raster::extract(sdm, bg)
  
  # taken from https://babichmorrowc.github.io/post/2019-04-12-sdm-threshold/
  
  if(type == "mtp"){
    thresh <- min(na.omit(occs_vals))
  } else if(type == "p10"){
    if(length(occs_vals) < 10){
      p10 <- floor(length(occs_vals) * 0.9)
    } else {
      p10 <- ceiling(length(occs_vals) * 0.9)
    }
    thresh <- rev(sort(occs_vals))[p10]
  } else if (type %in% c("kappa", "spec_sens", "no_omission", "prevalence", "equal_sens_spec", "sensitivity")) {

    #evaluate predictive ability of model
    ev <- dismo::evaluate(occs_vals, bg_vals)
    #detect possible thresholds 
    thr.table <- dismo::threshold(ev)
    
    thresh <- thr.table[, type]

  }
  

  
  return(thresh)
}

#' @name binarize_pred
#' @param obs data frame, containing the coordinates to reproject
#' @param predictors, raster
#' @param lon string, name of the longitude column (same projection as predictor raster)
#' @param lat string, name of the latitude column (same projection as predictor raster)
#' @param proj character, initial projection of the xy coordinates
#' @return spatial points
#' @import dplyr dismo raster
#' @export
binarize_pred <- function(sdm, threshold) {
  sdm[sdm < threshold] <- NA
  sdm[sdm >= threshold] <- 1
  return(sdm)
}


predict_maxent <- function(presence_background, 
  algorithm, 
                           predictors = NULL,
                           rm = 1, 
                           fc = "L",
                           type = "cloglog",
                           mask = NULL,
                           parallel = T,
                           updateProgress = T,
                           parallelType = "doParallel",
                           factors = c(),
                           output_folder = getwd()) {
  
  layers <- names(predictors)
  runs <- names(presence_background |> 
                  dplyr:: select(starts_with("run")))

  print("NUMBER OF RUNS :")
  print(length(runs))
  
  fc <- as.character(fc)
  rm <- as.numeric(rm)
  tuned_param <- sprintf("fc.%s_rm.%s", fc, rm)


  # We calculate the prediction with the whole dataset

      presence <- presence_background |> dplyr::filter(pa == 1) |> data.frame()
      background <- presence_background |> dplyr::filter(pa == 0) |> data.frame()
      

      mod_tuning <- ENMeval::ENMevaluate(occs = presence[, c("lon", "lat", layers)], 
                                         bg = background[, c("lon", "lat", layers)],  
                                         algorithm = "maxent.jar",
                                          partitions = "none", 
                                         tune.args = list(fc = fc, rm = rm),
                                         parallel =  parallel,
                                         updateProgress = updateProgress,
                                         parallelType = parallelType)
      
      
      pred_all <- dismo::predict(mod_tuning@models[[tuned_param]], predictors,
                                  args = sprintf("outputformat=%s", type))
      names(pred_all) <- "prediction"
# We calculate the prediction with subsets of the dataset
  if(length(runs) == 0) {
presence_background$run_1 <- 1
runs <- c("run_1")
      pred_runs <- pred_all
  } else {

  pred_runs <- NULL
  
  for (i in runs) {
    group.all <- presence_background |> dplyr::select(all_of(c(i, "scientific_name", "lon", "lat", "pa", layers)))
    group_folds <- group.all[,1]
    group  <- group_folds[presence_background$pa == 1]
    bg.grp <- group_folds[presence_background$pa == 0]
    occurrences <- group.all[group.all$pa == 1, c("lon", "lat")]#recria occs
    backgr      <- group.all[group.all$pa == 0, c("lon", "lat")]
    #para cada grupo
    for (g in setdiff(unique(group), 0)) {
      #excluding the zero allows for bootstrap. only 1 partition will run
      message(paste("run number", i, "part. nb.",
                    g))
      pres_train <- occurrences[group != g, ]
      if (nrow(occurrences) == 1) #only distance algorithms can be run
        pres_train <- occurrences[group == g, ]
      pres_test  <- occurrences[group == g, ]
      backg_test <- backgr[bg.grp == g, ]
      presence_bg_train <- group.all[which(group.all[,1] == g),]
      
      presence <- presence_bg_train |> dplyr::filter(pa == 1) |> data.frame()
      background <- presence_bg_train |> dplyr::filter(pa == 0) |> data.frame()
      

      mod_tuning <- ENMeval::ENMevaluate(occs = presence[, c("lon", "lat", layers)], 
                                         bg = background[, c("lon", "lat", layers)],  
                                         algorithm = "maxent.jar",
                                         categoricals = factors,
                                         partitions = "none", 
                                         tune.args = list(fc = fc, rm = rm),
                                         parallel =  parallel,
                                         updateProgress = updateProgress,
                                         parallelType = parallelType)
      
      
      pred_pres <- dismo::predict(mod_tuning@models[[tuned_param]], predictors,
                                  args = sprintf("outputformat=%s", type))

        if (inherits(pred_runs, "RasterLayer") || inherits(pred_runs, "RasterStack")) {
              pred_runs <- raster::stack(pred_runs, pred_pres)
         
        } else {
           pred_runs <-  pred_pres 
           }
      
 }

    }  
  }
  
  return(list("pred_all" = pred_all, "pred_runs" = pred_runs))
  }


  do_uncertainty <- function(path) {

    pred_rasters <- terra::rast(path) 

    if (terra::nlyr(pred_rasters) == 1) message("one single prediction - not calculating uncertainty.")
    e <- terra::ext(pred_rasters)
    raster_uncertainty <- terra::rast(e)
    values(raster_uncertainty)<-1
    if (terra::nlyr(pred_rasters) > 1) {
      raster_uncertainty <- terra::app(pred_rasters, fun = function(i) {max(i) - min(i) })
      names(raster_uncertainty) <- "raw_uncertainty"
     
    }

return(raster_uncertainty)
  }
  
