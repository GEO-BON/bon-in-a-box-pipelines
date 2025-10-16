library(terra)
library(tidyverse)
library(tools)

input <- biab_inputs()

# Rasterize country region
study_area <- terra::vect(input$study_area)
# Load denominator as target raster
denom <- rast(input$bilbi_denominator)

study_area_rast <- terra::rasterize(
  x = study_area,
  y = denom,
  field = 1, # The column in the SpatVector to use for values
  touches = TRUE # Optional: Include cells that are touched by the polygon
)

study_area_rast <- mask(study_area_rast, study_area)

### Summary function
summarize_BILBI <- function(bilbi_raster_path,
                            sumsimilarity_raster_path,
                            region_raster_path) {
  indicator_raster <- rast(bilbi_raster_path)
  denom <- sumsimilarity_raster_path
  map_raster <- region_raster_path


  # prepare cell-size area weights
  cell_areas <- cellSize(denom, unit = "m")
  # Extract the maximum cell area
  big_area <- global(cell_areas, fun = "max")$max # max area in square meters
  scaling_function <- function(values, areas) {
    return(values / areas)
  }
  # Divide the cell_areas raster by the maximum cell_size
  rowscaling_raster <- app(cell_areas, big_area, fun = scaling_function)
  print("area size weighting calculated")

  # set the denominator and indicator to NA if it is currently 0
  # denom[denom == 0] <- NA
  denom <- clamp(denom, lower = 0.000001, values = F) # this takes care of very low values in the dataset.
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
    return("indicator and denominator not identical projection, reprojecting")
    denom <- project(indicator_raster, denom)
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
summary_list <- list()
for (i in 1:length(input$bilbi_indicator)) {
  path <- input$bilbi_indicator[i]
  summary <- summarize_BILBI(bilbi_raster_path = path, sumsimilarity_raster_path = denom, region_raster_path = study_area_rast)
  summary$date <- as.Date(str_extract(path, "\\d{4}-\\d{2}-\\d{2}"))
  summary_list[[i]] <- summary
}
summary_list <- do.call(rbind, summary_list)

summary_path <- file.path(outputFolder, "summary.csv")
write.csv(summary_list, summary_path, row.names = F)

biab_output("summarised_values", summary_path)

# Plot time series
result_yrs_plot <-
    ggplot(
      summary_list,
      aes(x = date, y = BILBI_indicator)
    ) +
    geom_point(size=4, color="#078c83") +
    geom_line(size=1.5, color="#078c83") +
    labs(y = "Indicator value", x = "Date") +
    theme_bw()

file_path <- file.path(outputFolder, paste0("result_plot.png"))
ggsave(file_path, result_yrs_plot)


biab_output("time_series_plot", file_path)