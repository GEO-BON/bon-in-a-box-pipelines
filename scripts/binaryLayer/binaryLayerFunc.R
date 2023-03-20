#' @name binary_layer 
#' @param class_lc Vector of integers, list of land cover classes to select 
#' @param threshold_prop, float value indicating land cover proportion threshold. Values below threshold are converted to zero and above it to 1.
#' @return a raster stack binary land cover classes 
#' @import raster dplyr 
#' @export

binary_layer <- function(lc_classes, 
                         select_class = input$select_class,
                         threshold_prop = input$threshold_prop){ 

# let's create a raster stack for all classes and keep original classes names
  
  lc_classes_stack <- raster::stack(lc_classes)

# object to save the list of short names
  shortnames <- list()
  
  for(j in 1:length(lc_classes)){
    
    read_lc <- lapply(lc_classes[j], function(y){lc_classes[grep(pattern = y, x = lc_classes)]})
    
    shortnames[[j]] <- gsub(".*/(.*)\\..*", "\\1", read_lc)
      
  }
  
  names(lc_classes_stack) <- c(unlist(c(shortnames)))

# Creating reclassification matrix based on threshold_prop
  m <- c(0, threshold_prop, 0, threshold_prop, 1, 1)
  rclmat <- matrix(m, ncol=3, byrow=T)

  # Looping within  land cover classes (select_class)

  # object to save the list of rasters
    lc_threshold <- list() 

    for(i in 1:length(select_class)){
        read_lc_sel  <- raster::subset(lc_classes_stack,
                                       grep(select_class[i], names(lc_classes_stack), ignore.case = TRUE)
                                       )
        # Reclassify
        read_lc_r <- reclassify(read_lc_sel, rclmat)
     
      # Rename raster
        names(read_lc_r) <- paste0(names(read_lc_sel),  "_binary")
    
      # Save list
        lc_threshold[[i]] <- read_lc_r
      #
    }
   
  lc_threshold_s <- raster::stack(lc_threshold) # stack rasters
 
  return(lc_threshold_s)

}
