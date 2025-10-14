library(terra)
library(tidyverse)
library(tools)

# Rasterize country region


### Summary function
summarize_BILBI <- function(bilbi_raster_path,          
                            sumsimilarity_raster_path,    
                            region_raster_path)   
{
indicator_raster <- rast(bilbi_raster_path)
denom <- rast(sumsimilarity_raster_path)
map_raster <- rast(region_raster)

# prepare cell-size area weights
  cell_areas <- cellSize(denom, unit = "m")
  # Extract the maximum cell area
  big_area <- global(cell_areas, fun="max")$max  # max area in square meters
  scaling_function <- function(values, areas) {
    return(values / areas)
  }
  # Divide the cell_areas raster by the maximum cell_size
  rowscaling_raster <- app(cell_areas, big_area, fun = scaling_function)
  print("area size weighting calculated")
  
  # set the denominator and indicator to NA if it is currently 0
  # denom[denom == 0] <- NA
  denom <- clamp(denom, lower = 0.000001, values=F)  # this takes care of very low values in the dataset.
  reciprocal_denom <- 1 / denom
  indicator_raster[indicator_raster == 0] <- NA
  print("reciprocal_denom made")
  
  # Ensure all rasters have the same geometry. DENOM and INDICATOR must be correctly projected geographic, identical
  identical_geometry <- compareGeom(denom, map_raster, crs = TRUE, ext = TRUE, res = TRUE, stopOnError = FALSE)
  if (!identical_geometry) {
    denom <- project(map_raster, denom)
  }
  identical_geometry <- compareGeom(denom, indicator_raster, crs = TRUE, ext = TRUE, res = TRUE, stopOnError = FALSE)
  if (!identical_geometry) {
    return("indicator and denominator not identical projection")
  }
  print("geometry checked")
  
  # Safe logarithm function to avoid negative or zero values
  safe_log_function <- function(x) {
    ifelse(x > 0, log(x), NA)
  }
  
  # Apply the logarithm
  log_indicator <- app(indicator_raster, fun = safe_log_function)
  print("indicator logged")
  
  # Scale the indicator and denom
  top_term <- log_indicator / denom
  top_term <- top_term * rowscaling_raster
  print("area weight applied")
  
  bottom_term <- reciprocal_denom * rowscaling_raster
  
  # Calculate zonal statistics
  numerator_region <- zonal(top_term, map_raster, fun = "sum", na.rm = TRUE)
  denominator_region <- zonal(bottom_term, map_raster, fun = "sum", na.rm = TRUE)
  
  # Prepare output
  output <- data.frame(
    region = numerator_region[, 1],
    BILBI_indicator = exp(numerator_region[, 2] / denominator_region[, 2]),
    num = numerator_region,
    den = denominator_region
  )
  
  # return the regional indicator
  return(output)
  
} # end summarize_BILBI function

# Loop through each year
for i in 1:length(input$BILBI_indicator){
summary <- summarise_BILBI(input$BILBI_indicator[i], input$BILBI_demoninator, country_region_raster)
}

# Plot time series