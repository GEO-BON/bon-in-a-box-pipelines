  range_predictions_old <- function(folder) {
    
    files <- list.files(folder, pattern = "*.tif$", full.names = TRUE)
    range <- NULL
    if (length(files) == 0) {
      stop(sprintf("No tif files found in the directory %s", folder))
      
    } else if (length(files) == 1) {
      stop("One single prediction - not calculating uncertainty.")
   } else if (length(files) > 1) {
    #Load rasterss
    predictions <- lapply(files,
                             terra::rast)
    predictions <- terra::rast(predictions)
    range <- terra::app(predictions, fun = function(i) {max(i) - min(i) })
      names(range) <- "range_predictions"
     
    }

return(range)
  }
  

  range_predictions <- function(predictions) {
    # transform the list into a terra rast object
    predictions <- terra::rast(predictions)
    #range <- terra::app(predictions, fun = function(i) {quantile(i,0.975) - quantile(i,0.025) })
    range <- quantile(predictions, probs = c(0.025 , 0.975))
    names(range) <- c("range_predictions_0.025", "range_predictions_0.975")
    return(range)
  }
  
