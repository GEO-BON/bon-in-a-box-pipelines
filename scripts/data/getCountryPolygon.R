library(sf)
library(rjson)
library(dplyr)
library(countrycode)
library(httr2)

if (!requireNamespace("packageName", quietly = TRUE)) {
  remotes::install_github("ropensci/rnaturalearthhires")
}

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

# Change from ISO code to country namelibrary(countrycode)
country_name <- countrycode(
  input$country,
  origin = "iso3c",
  destination = "country.name.en"
)

biab_output("country", country_name)

if (is.null(input$region)) { # pull study area polygon
  # pull whole country
  tryCatch(
    {
      res <- request(paste0("https://www.geoboundaries.org/api/current/gbOpen/", input$country, "/ADM0")) |>
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
      res <- request(paste0("https://www.geoboundaries.org/api/current/gbOpen/", input$country, "/ADM1")) |> # ADM1 gives states and provinces
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

  print(country_region_polygon$shapeName)
  shapeName <- paste(country_region_polygon$shapeName, collapse = ", ")
  country_region_polygon <- country_region_polygon[country_region_polygon$shapeName == input$region, ] # filter shape by region of interest

  if (nrow(country_region_polygon) == 0) {
    biab_error_stop(paste0("Could not find polygon. Check that you have correct region name. Valid region names are:", shapeName))
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
