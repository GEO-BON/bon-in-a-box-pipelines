library(duckdb)
library(sf)
library(dplyr)
if (!require("duckdbfs")) {
  install.packages("duckdbfs")
}
library(duckdbfs)

input <- biab_inputs()
print(input$country_region$country$englishName)

lazy_geo_data <- open_dataset("https://object-arbutus.cloud.computecanada.ca/bq-io/vectors-cloud/marine_regions_eez/eez_v12.parquet")
print(input$country$englishName)

geo_data_sf <- lazy_geo_data |> filter(TERRITORY1 == input$country_region$country$englishName) |> to_sf() |> st_set_crs(4326)
geo_data_sf$fid <- as.integer(geo_data_sf$fid)

print(class(geo_data_sf))

eez_path <- file.path(outputFolder, "eez.gpkg")
st_write(geo_data_sf, eez_path) 
biab_output("eez", eez_path)