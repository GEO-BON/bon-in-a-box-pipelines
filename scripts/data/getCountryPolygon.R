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


if (is.null(input$region)) { # pull study area polygon from rnaturalearth
  # pull whole country
  res <- request(paste0("https://www.geoboundaries.org/api/current/gbOpen/", input$country, "/ADM0")) |> 
  req_perform()

  meta <- res |> resp_body_json() # parse JSON

  geojson_url <- meta$gjDownloadURL # Extract the GeoJSON download URL

  country_polygon <- st_read(geojson_url) # Load geojson
  
} else {
  print("pulling region polygon")
  res <- request(paste0("https://www.geoboundaries.org/api/current/gbOpen/", input$country, "/ADM1")) |> 
  req_perform() # ADM1 gives regions/provinces

  meta <- res |> resp_body_json() 

  geojson_url <- meta$gjDownloadURL 

  country_polygon <- st_read(geojson_url)

  print(country_polygon$shapeISO)
  country_polygon <- country_polygon[country_polygon$shapeISO == input$region, ] # filter shape by region of interest
}

if (nrow(country_polygon) == 0) {
  biab_error_stop("Could not find polygon. Check spelling of country and state names.")
} # stop if object is empty

# transform to crs of interest
country_polygon <- st_transform(country_polygon, crs = input$crs)
print(st_crs(country_polygon))

print("Study area downloaded")
print(class(country_polygon))

# output country polygon
country_polygon_path <- file.path(outputFolder, "country_polygon.gpkg")
sf::st_write(country_polygon, country_polygon_path, delete_dsn = T)
biab_output("country_polygon", country_polygon_path)
