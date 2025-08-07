library(sf)
library(rjson)
library(dplyr)
library(countrycode)
library(httr2)

input <- biab_inputs()

# Output country and region
if (is.null(input$country)) {
  country <- "No country chosen"
} else {
  country <- input$country
}

if (is.null(input$region)) {
  region <- "No region chosen"
} else {
  region <- input$region
}

biab_output("region", region)

if (is.null(input$subregion)) {
  region <- "No sub-region chosen"
} else {
  region <- input$region
}

# Change from ISO code to country namelibrary(countrycode)
country_name <- countrycode(
  input$country,
  origin = "iso3c",
  destination = "country.name.en"
)

biab_output("country", country_name)


if (is.null(input$region) & is.null(input$subregion)) { # pull study area polygon
  # pull whole country
  tryCatch(
    {
      res <- request(paste0("https://www.geoboundaries.org/api/current/gbOpen/", input$country, "/ADM1")) |>
        req_perform()
    },
    error = function(e) {
      if (grepl("404|Not Found", e$message)) {
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
    biab_error_stop(paste0("Could not find polygon. Check that you have correct country code. "))
  } # stop if object is empty
} else if (is.null(input$subregion)) {
  print("pulling region polygon")
  res <- request(paste0("https://www.geoboundaries.org/api/current/gbOpen/", input$country, "/ADM1")) |>
    req_perform() # ADM1 gives regions/provinces

  meta <- res |> resp_body_json()

  geojson_url <- meta$gjDownloadURL

  country_region_polygon <- st_read(geojson_url)

  print(country_region_polygon$shapeName)
  shape_names_str <- paste(country_region_polygon$shapeName, collapse = ", ")
  country_region_polygon <- country_region_polygon[country_region_polygon$shapeName == input$region, ] # filter shape by region of interest
  if (nrow(country_region_polygon) == 0) {
    print(shape_names_str)
    biab_error_stop(paste0("Could not find polygon. Check that you have correct country codes and region names. Valid inputs are: ", shape_names_str))
  } # stop if object is empty
} else {
  res <- request(paste0("https://www.geoboundaries.org/api/current/gbOpen/", input$country, "/ADM2")) |>
    req_perform() # ADM2 gives subregions

  meta <- res |> resp_body_json()

  geojson_url <- meta$gjDownloadURL

  country_region_polygon <- st_read(geojson_url)

  print(country_region_polygon$shapeName)
  shape_names_str <- paste(country_region_polygon$shapeName, collapse = ", ")
  country_region_polygon <- country_region_polygon[country_region_polygon$shapeName == input$subregion, ] # filter shape by region of interest

  if (nrow(country_region_polygon) == 0) {
    biab_error_stop(paste0("Could not find polygon. Check that you have correct country codes and region names. Valid inputs are: ", shape_names_str))
  } # stop if object is empty
}


# transform to crs of interest
country_region_polygon <- st_transform(country_region_polygon, crs = input$crs)
print(st_crs(country_region_polygon))

print("Study area downloaded")
print(class(country_region_polygon))

# output country polygon
country_region_polygon_path <- file.path(outputFolder, "country_region_polygon.gpkg")
sf::st_write(country_region_polygon, country_region_polygon_path, delete_dsn = T)
biab_output("country_region_polygon", country_region_polygon_path)
