library(sf)
library(rjson)
library(rnaturalearth)
library(rnaturalearthdata)
library(dplyr)
library(countrycode)

if (!requireNamespace("packageName", quietly = TRUE)) {
  remotes::install_github("ropensci/rnaturalearthhires")
}

input <- biab_inputs()

# Output country and region
if(is.null(input$country)){
  country <- "No country chosen"
} else {country <- input$country}

if(is.null(input$region)){
  region <- "No region chosen"
} else {region <- input$region}

biab_output("region", region)

# Change from ISO code to country namelibrary(countrycode)
country_name <- countrycode(
  input$country,
  origin="iso3c",
  destination="country.name.en")

biab_output("country", country_name)


if(is.null(input$region)){ # pull study area polygon from rnaturalearth
   # pull whole country
   print("pulling country polygon")
    country_polygon <- ne_countries(country=country_name, type = "countries", scale = "medium")
  } else {
  print("pulling region polygon")
  country_polygon <- ne_states(country=input$country)
  country_polygon <- country_polygon %>% filter(name==input$region)
  }

if(nrow(country_polygon)==0){
  stop("Could not find polygon. Check spelling of country and state names.")
}  # stop if object is empty

# transform to crs of interest
country_polygon <- st_transform(country_polygon, crs=input$crs)
print(st_crs(country_polygon))

print("Study area downloaded")
print(class(country_polygon))

# output country polygon
country_polygon_path <- file.path(outputFolder, "country_polygon.gpkg")
sf::st_write(country_polygon, country_polygon_path, delete_dsn = T)
biab_output("country_polygon", country_polygon_path)
