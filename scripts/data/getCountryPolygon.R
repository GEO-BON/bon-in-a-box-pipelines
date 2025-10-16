library(sf)
library(rjson)
library(dplyr)
library(countrycode)
library(httr2)

input <- biab_inputs()
crs <- paste0(input$bbox_crs$CRS$authority, ":", input$bbox_crs$CRS$code)

# Output country and region
country <- input$bbox_crs$country$ISO3

if (is.null(input$bbox_crs$region)) {
  region <- "No region chosen"
} else {
  region <- input$bbox_crs$region$regionName
}

biab_output("region", region)

# Change from ISO code to country namelibrary(countrycode)
country_name <- countrycode(
  country,
  origin = "iso3c",
  destination = "country.name.en"
)

biab_output("country", country_name)

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

  if (nrow(country_region_polygon) == 0) {
    biab_error_stop("Could not find polygon. Check that you have correct country code.")
  }
} else {
  print("pulling region polygon")
  tryCatch(
    {
      res <- request(paste0("https://www.geoboundaries.org/api/current/gbOpen/", country, "/ADM1")) |> # ADM1 gives states and provinces
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

  meta <- res |> resp_body_json()

  geojson_url <- meta$gjDownloadURL

  country_region_polygon <- st_read(geojson_url)
  country_region_polygon <- st_transform(country_region_polygon, crs = crs)

  bbox_values <- (input$bbox_crs$bbox)
  names(bbox_values) <- c("xmin", "ymin", "xmax", "ymax")
  bbox_poly <- st_as_sfc(st_bbox(bbox_values, crs = crs))

  # Find all regions that intersect the bbox
  intersections <- st_intersection(country_region_polygon, bbox_poly)

  # Compute area of each intersection
  intersections$overlap_area <- st_area(intersections)

  # Pick the one with the largest overlap
  best_idx <- which.max(intersections$overlap_area)
  best_region_name <- intersections$shapeName[best_idx]
  print(best_region_name)

  # Filter to that region
  country_region_polygon <- country_region_polygon[country_region_polygon$shapeName == best_region_name, ]
  print(country_region_polygon)
  # Optional: print which region was chosen
  print(paste("Selected region:", best_region_name))

  # print(country_region_polygon$shapeName)
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
print(class(country_region_polygon))

# output country polygon
country_region_polygon_path <- file.path(outputFolder, "country_region_polygon.gpkg")
sf::st_write(country_region_polygon, country_region_polygon_path, delete_dsn = T)
biab_output("country_region_polygon", country_region_polygon_path)
