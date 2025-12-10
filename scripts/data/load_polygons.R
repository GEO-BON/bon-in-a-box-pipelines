library(duckdb)
library(sf)
library(dplyr)
if (!require("duckdbfs")) {
    install.packages("duckdbfs")
}
if (!require("duckspatial")) {
    install.packages("duckspatial")
}
library(duckdbfs)
library(duckspatial)

input <- biab_inputs()

# Load country region polygon
if (input$polygon_type == "Country or region" | input$polygon_type == "WDPA") {
    # Load country if region is null
    if (is.null(input$country_region$region)) {
        country <- open_dataset("https://data.fieldmaps.io/adm0/osm/intl/adm0_polygons.parquet")
        geo_data_sf <- country |>
            filter(adm0_src == input$country_region$country$ISO3) |>
            to_sf() |>
            st_set_crs(4326)
    } else if (is.null(input$country_region$country) & is.null(input$country_region$region)) { # if both are null (custom bounding box)
        bbox_values <- (input$bbox_crs$bbox)
        names(bbox_values) <- c("xmin", "ymin", "xmax", "ymax")
        geo_data_sf <- st_as_sfc(st_bbox(bbox_values, crs = crs)) ### need to assign CRS
        # transform back to 4326 if not already NEED TO DO THIS
    } else { # if there is country and region
        country_region <- open_dataset("https://data.fieldmaps.io/edge-matched/humanitarian/intl/adm1_polygons.parquet")
        geo_data_sf <- country_region |>
            filter(adm0_src == input$country_region$country$ISO3) |> filter(adm1_name == input$country_region$region$regionName) |>
            to_sf() |>
            st_set_crs(4326)
            geo_data_sf$fid <- as.integer(geo_data_sf$fid)
    }
    print(geo_data_sf)
}

if (input$polygon_type == "WDPA") {
country_region_polygon <- geo_data_sf
print(colnames(country_region_polygon))
url <- "https://object-arbutus.cloud.computecanada.ca/bq-io/vectors-cloud/wdpa/wdpa.parquet"

con <- dbConnect(duckdb())

dbExecute(con,"INSTALL spatial; INSTALL httpfs; LOAD spatial; LOAD httpfs;")

ddbs_write_vector(
con,
country_region_polygon,
"region",
overwrite = TRUE
)

buffer <- input$buffer

wdpa_area<-dbExecute(con,paste0("CREATE OR REPLACE VIEW tmp AS SELECT w.* FROM read_parquet('",url,"') w, region WHERE st_intersects(w.SHAPE,region.geom)"))

geo_data_sf <- ddbs_read_vector(con, "tmp") |> st_set_crs(4326)
print(geo_data_sf)
}

if (input$polygon_type == "EEZ") {
    eez <- open_dataset("https://object-arbutus.cloud.computecanada.ca/bq-io/vectors-cloud/marine_regions_eez/eez_v12.parquet")
    print(input$country$englishName)

    geo_data_sf <- eez |>
        filter(TERRITORY1 == input$country_region$country$englishName) |>
        to_sf() |>
        st_set_crs(4326)
    geo_data_sf$fid <- as.integer(geo_data_sf$fid)

    if (nrow(geo_data_sf)==0){
        biab_error_stop("There is no Exclusive Economic Zone for this country")
    }
}

# Transform to crs of interest

polygon_path <- file.path(outputFolder, "polygon.gpkg")
st_write(geo_data_sf, polygon_path)
biab_output("polygon", polygon_path)
