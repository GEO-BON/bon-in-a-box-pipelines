# value = FALSE if instead of image values a map of just presence of the values is required
# type_min either 1 for ">=", 2 for ">" or 3 for equal
# type_max define 1 for "<=", 2 for "<" or 3 for equal
library(purrr)
library(gdalcubes)

funFilterCube_range <- as_mapper(function(cube, min=NA , max=NA, type_min=1 , type_max=1 , value=TRUE){
  condition <- case_when(!is.na(min) & !is.na(max) ~ 1, # for minimum and equal min value and maximum and equal max value filter
                         !is.na(min) &  is.na(max) ~ 2, # for just maximum and equal max value filter
                         is.na(min) & !is.na(max) ~ 3) # for just minimum and equal min value filter
  
  type_min <- case_when(type_min == 1 ~ ">=",
                        type_min == 2 ~ ">" ,
                        type_min == 3 ~ "==") 
  type_max <- case_when(type_max == 1 ~ "<=",
                        type_max == 2 ~ "<" ,
                        type_max == 3 ~ "==" )
  
  if(type_min == 3 & type_max == 3) stop("Only one value should be assigned for min or max to get filter by this value")
  
  if(value == TRUE){
    if(condition == 1){ # if both values are given
      cube_filtered <<- cube |>
        gdalcubes::filter_pixel(paste0("data",type_max, max)) |>
        gdalcubes::filter_pixel(paste0("data",type_min, min)) 
      message("Filter: ", paste0("data",type_min, min) , " & ", paste0("data",type_max, max))
    }else{ # if only one value exist
      if(condition == 2){ 
        cube_filtered <<- cube |>
          gdalcubes::filter_pixel(paste0("data",type_min, min)) 
        message("Filter: ",paste0("data",type_min, min))
      }
      if(condition == 3){
        cube_filtered <<- cube |>
          gdalcubes::filter_pixel(paste0("data",type_max, max)) 
        message("Filter: ",paste0("data",type_max, max))
      }
    }
  }else{
    if(condition == 1){ # if both values are given
      cube_filtered <<- cube |>
        gdalcubes::filter_pixel(paste0("data",type_max, max)) |>
        gdalcubes::filter_pixel(paste0("data",type_min, min)) |> gdalcubes::apply_pixel("data/data")
      message("Filter: ", paste0("data",type_min, min), " & ", paste0("data",type_max, max))
    }else{ # if only one value exist
      if(condition == 2){ 
        cube_filtered <<- cube |>
          gdalcubes::filter_pixel(paste0("data",type_min, min)) |> gdalcubes::apply_pixel("data/data")
        message("Filter: ",paste0("data",type_min, min))
      }
      if(condition == 3){
        cube_filtered <<- cube |>
          gdalcubes::filter_pixel(paste0("data",type_max, max)) |> gdalcubes::apply_pixel("data/data")
        message("Filter: ",paste0("data",type_max, max))
      }
    }
  }
  return(cube_filtered)
}
)