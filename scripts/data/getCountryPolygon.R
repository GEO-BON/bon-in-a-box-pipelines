library(sf)
library(rjson)
library(dplyr)
library(countrycode)
library(httr2)

if (!requireNamespace("packageName", quietly = TRUE)) {
  remotes::install_github("ropensci/rnaturalearthhires")
}

input <- biab_inputs()

if (is.null(input$region)) {
  region <- "No region chosen"
} else {
  region <- input$region
}

biab_output("region", region)

if (!is.null(input$country)) {
  country <- input$country

  # Change from ISO code to country namelibrary(countrycode)
  country_name <- countrycode(
    input$country,
    origin = "iso3c",
    destination = "country.name.en"
  )

  biab_output("country", country_name)


if (is.null(input$region)) { # pull study area polygon from rnaturalearth
  # pull whole country
  res <- request(paste0("https://www.geoboundaries.org/api/current/gbOpen/", input$country, "/ADM0")) |>
  req_perform()

    meta <- res |> resp_body_json() # parse JSON

    geojson_url <- meta$gjDownloadURL # Extract the GeoJSON download URL

  country_region_polygon <- st_read(geojson_url) # Load geojson

} else {
  print("pulling region polygon")
  res <- request(paste0("https://www.geoboundaries.org/api/current/gbOpen/", input$country, "/ADM1")) |>
  req_perform() # ADM1 gives regions/provinces

  meta <- res |> resp_body_json()

  geojson_url <- meta$gjDownloadURL

  country_region_polygon <- st_read(geojson_url)

  print(country_region_polygon$shapeISO)
  country_region_polygon <- country_region_polygon[country_region_polygon$shapeISO == input$region, ] # filter shape by region of interest
}
