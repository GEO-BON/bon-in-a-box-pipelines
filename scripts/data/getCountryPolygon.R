library(sf)
library(rjson)
library(dplyr)
library(countrycode)
library(httr2)

input <- biab_inputs()
crs <- paste0(input$bbox_crs$CRS$authority, ":", input$bbox_crs$CRS$code)

# Output country and region
country <- input$bbox_crs$country$ISO3
print(country)

if (is.null(input$bbox_crs$region)) {
  region <- "No region chosen"
} else {
  region <- input$bbox_crs$region$regionName
}
print(region)
biab_output("region", region)

biab_output("country", input$bbox_crs$country$englishName)

if (is.null(input$bbox_crs$region)) { # pull study area polygon
  # pull whole country
  tryCatch(
    {
      res <- request(paste0("https://www.geoboundaries.org/api/current/gbOpen/", country, "/ADM0")) |>
        req_perform()
    },
    error = function(e) {
      if (grepl("404", e$message)) {
        biab_error_stop("Could not find polygon. Check that you have correct country code.")
      } else {
        stop(e) # re-throw any other error
      }
    }
  )

  meta <- res |> resp_body_json() # parse JSON

  geojson_url <- meta$gjDownloadURL # Extract the GeoJSON download URL

  country_region_polygon <- st_read(geojson_url) # Load geojson
  country_region_polygon <- st_transform(country_region_polygon, crs = crs)

  if (nrow(country_region_polygon) == 0) {
    biab_error_stop("Could not find polygon. Check that you have correct country code.")
  }
} else {
  print("pulling region polygon")
  adm_code <- "/ADM1"
  exceptions <- c("ITA", "BEL") # countries where the states are in ADM2
  if (country %in% exceptions) {
    adm_code <- "/ADM2"
  }
  tryCatch(
    {
      res <- request(paste0("https://www.geoboundaries.org/api/current/gbOpen/", country, adm_code)) |> # ADM1 gives states and provinces
        req_perform()
    },
    error = function(e) {
      if (grepl("404", e$message)) {
        biab_error_stop("Could not find polygon. Check that you have correct country code.")
      } else {
        stop(e) # re-throw any other error
      }
    }
  )
  # # Find all regions that intersect the bbox
  # intersections <- st_intersection(country_region_polygon, bbox_poly)

  # # Compute area of each intersection
  # intersections$overlap_area <- st_area(intersections)

  # # Pick the one with the largest overlap
  # best_idx <- which.max(intersections$overlap_area)
  # best_region_name <- intersections$shapeName[best_idx]

  # # Filter to that region
  # country_region_polygon <- country_region_polygon[country_region_polygon$shapeName == best_region_name, ]
  meta <- res |> resp_body_json()
  geojson_url <- meta$gjDownloadURL

  country_region_polygon <- st_read(geojson_url)
  country_region_polygon <- st_transform(country_region_polygon, crs = crs)

  print(country_region_polygon$shapeName)
  # country_region_polygon_path <- file.path(outputFolder, "country_region_polygon.gpkg")
  # sf::st_write(country_region_polygon, country_region_polygon_path, delete_dsn = T)
  # biab_output("country_region_polygon", country_region_polygon_path)

  bbox_values <- (input$bbox_crs$bbox)
  names(bbox_values) <- c("xmin", "ymin", "xmax", "ymax")
  bbox_poly <- st_as_sfc(st_bbox(bbox_values, crs = crs))
  bbox_poly <- st_buffer(bbox_poly, dist = 10000)

  # country_region_polygon_path <- file.path(outputFolder, "bbox_poly.gpkg")
  # sf::st_write(bbox_poly, country_region_polygon_path, delete_dsn = T)
  # biab_output("country_region_polygon", country_region_polygon_path)

  country_region_polygon <- country_region_polygon[st_within(country_region_polygon, bbox_poly, sparse = FALSE), ]
  print(paste("Selected region:", country_region_polygon$shapeName))
  # shapeName <- paste(country_region_polygon$shapeName, collapse = ", ")
  # country_region_polygon <- country_region_polygon[country_region_polygon$shapeName == input$region, ] # filter shape by region of interest

  if (nrow(country_region_polygon) == 0) {
    biab_error_stop(paste0("Could not find polygon. Check that you have correct region name."))
  } # stop if object is empty
}

# transform to crs of interest
# country_region_polygon <- st_transform(country_region_polygon, crs = crs)
print(st_crs(country_region_polygon))

print("Study area downloaded")

# output country polygon
country_region_polygon_path <- file.path(outputFolder, "country_region_polygon.gpkg")
sf::st_write(country_region_polygon, country_region_polygon_path, delete_dsn = T)
biab_output("country_region_polygon", country_region_polygon_path)
