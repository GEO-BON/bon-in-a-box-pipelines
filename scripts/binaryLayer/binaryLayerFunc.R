#' @name binary_layer 
#' @param class_lc Vector of integers, list of land cover classes to select 
#' @param threshold_prop, float value indicating land cover proportion threshold. Values below threshold are converted to zero and above it to 1.
#' @return a raster stack binary land cover classes 
#' @import raster dplyr 
#' @export

binary_layer <- function(lc_classes, 
                         select_class = c(210, 60),
                         threshold_prop = 0.8){ 
print(paste("TEMP lc_classes", lc_classes))
# Creating reclassification matrix based on threshold_prop
  m <- c(0, threshold_prop, 0, threshold_prop, 1, 1)
  rclmat <- matrix(m, ncol=3, byrow=T)

# Looping within  land cover classes (select_class)

  # object to save the list of rasters
    lc_threshold <- list() 
    shortnames <- list()
  
  # Loop
    for(i in 1:length(select_class)){
        lc_stack <- raster::stack(lc_classes)

        print(paste("TEMP names stack", names(lc_stack)))
      # Read list of input and create rasters
        read_lc  <- raster::subset(lc_stack,
                                 grep(select_class[i],
                                      names(lc_stack),
                                      ignore.case = TRUE))
        
      # Reclassify raster based on threshold
        read_lc_r <- reclassify(read_lc, rclmat)
     
      # Rename raster
        names(read_lc_r) <- paste0(names(read_lc),  "_binary")
     
      # Save list
        lc_threshold[[i]] <- read_lc_r
     
    }
   
  lc_threshold_s <- stack(lc_threshold) # stack rasters
 
  return(lc_threshold_s)

}
