# This is to look at change in BII over time
library("rjson")
library("terra")
library("dplyr")

input <- biab_inputs()
start_years <- list("2000", "2005", "2010", "2015")
end_years <- list("2005", "2010", "2015", "2020")

if (is.null(input$start_year)) {
  start_yr <- "bii_nhm_10km_2000"
}

if (is.null(input$end_year)) {
  end_yr <- "bii_nhm_10km_2020"
}


if (!is.null(input$start_year) && !is.null(input$end_year)) {
  if (!(input$start_year %in% start_years) || !(input$end_year %in% end_years)) {
    biab_error_stop("Invalid input for start or end year. The options are 2000, 2005, 2010, 2015 or 2020.")
  }

  if (input$start_year >= input$end_year) {
    biab_error_stop("Input years seem reversed. Please double check your inputs.")
  }

  if (!(input$start_year %in% start_years) || !(input$end_year %in% end_years)) {
    biab_error_stop(paste(
      "Invalid input for start or end year. The options are \n",
      " - Start year:",
      paste(start_years, collapse = ", "),
      "\n - End year:",
      paste(end_years, collapse = ", ")
    ))
  }

  start_yr <- paste0("bii_nhm_10km_", input$start_year)
  end_yr <- paste0("bii_nhm_10km_", input$end_year)
}

# Load rasters as a raster stack
rasters <- terra::rast(c(input$rasters))
print(terra::time(rasters))
print((rasters))

first_raster <- rasters[[1]]
end_raster <- rasters[[nlyr(rasters)]]

print(names(first_raster))
# Summarise
bii_change <- first_raster - end_raster

# Output
bii_change_path <- file.path(outputFolder, "BII_change.tif")
writeRaster(bii_change, bii_change_path)
biab_output("bii_change", bii_change_path)
