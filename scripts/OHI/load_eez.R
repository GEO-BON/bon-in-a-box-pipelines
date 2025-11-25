#if (!require("mregions2")) {
pak::pak("mregions2")
#  }

library(mregions2)
library(sf)

inputs <- biab_inputs()
# Search for EEZ layers that match the country name
print(input$country)
search_result <- mr_search(input$country, dataset = "eez")

eez <- mr_get(search_result, format = "sf")

eez_polygon_path <- file.path(outputFolder, "eez_polygon.gpkg")
sf::st_write(eez, eez_polygon_path, delete_dsn = T)
biab_output("eez", eez_polygon_path)
