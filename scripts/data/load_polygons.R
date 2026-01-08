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
            filter(adm0_src == input$country_region$country$ISO3) |>
            filter(adm1_name == input$country_region$region$regionName) |>
            to_sf() |>
            st_set_crs(4326)
        geo_data_sf$fid <- as.integer(geo_data_sf$fid)
    }
    print(geo_data_sf)
}

if (input$polygon_type == "WDPA") {
    country_region_polygon <- geo_data_sf
    print(colnames(country_region_polygon))

    con <- dbConnect(duckdb())

    dbExecute(con, "INSTALL spatial; LOAD spatial; INSTALL httpfs; LOAD httpfs;")
    dbExecute(con, 'CREATE OR REPLACE VIEW wdpa AS SELECT * FROM read_parquet("https://object-arbutus.cloud.computecanada.ca/bq-io/vectors-cloud/wdpa/wdpa.parquet")')

    if (!is.null(input$country_region$region$regionName)) {
        dbExecute(con, paste0("CREATE OR REPLACE TABLE region AS SELECT * FROM 'https://data.fieldmaps.io/edge-matched/humanitarian/intl/adm1_polygons.parquet' WHERE adm0_src='", input$country_region$country$ISO3, "' and adm1_name='", input$country_region$region$regionName,"'")); 
    } else {
        dbExecute(con, paste0("CREATE OR REPLACE TABLE region AS SELECT * FROM 'https://data.fieldmaps.io/adm0/osm/intl/adm0_polygons.parquet' WHERE adm0_src='", input$country_region$country$ISO3,"'"))
    }
    dbExecute(con, "CREATE OR REPLACE TABLE wdpa_region AS (WITH reg AS (
        SELECT
            geometry_bbox.xmin AS xmin_r,
            geometry_bbox.ymin AS ymin_r,
            geometry_bbox.xmax AS xmax_r,
            geometry_bbox.ymax AS ymax_r
        FROM region
    )
    SELECT w.* EXCLUDE(geom_wkt, bbox)
    FROM wdpa w, reg r
    WHERE
        bbox.xmax >= r.xmin_r AND
        bbox.xmin <= r.xmax_r AND
        bbox.ymin <= r.ymax_r AND
        bbox.ymax >= r.ymin_r)")

    dbExecute(con, paste0("COPY (SELECT w.* FROM wdpa_region w, region r WHERE ST_DWithin(w.geometry,r.geometry,", input$buffer, ")) TO '/", outputFolder, "/polygon.gpkg' (DRIVER 'GPKG', FORMAT gdal)"))
}


if (input$polygon_type == "EEZ") {
    eez <- open_dataset("https://object-arbutus.cloud.computecanada.ca/bq-io/vectors-cloud/marine_regions_eez/eez_v12.parquet")
    print(input$country$englishName)

    geo_data_sf <- eez |>
        filter(TERRITORY1 == input$country_region$country$englishName) |>
        to_sf() |>
        st_set_crs(4326)
    geo_data_sf$fid <- as.integer(geo_data_sf$fid)

    if (nrow(geo_data_sf) == 0) {
        biab_error_stop("There is no Exclusive Economic Zone for this country")
    }
}

polygon_path <- file.path(outputFolder, "polygon.gpkg")
# st_write(geo_data_sf, polygon_path)
biab_output("polygon", polygon_path)
