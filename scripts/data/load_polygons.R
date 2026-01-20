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


Sys.setenv(HOME = "/output")

input <- biab_inputs()

crs_input <- paste0(input$country_region$CRS$authority, ":", input$country_region$CRS$code)
polygon_path <- file.path(outputFolder, "polygon.gpkg")

# Load country region polygon
if (input$polygon_type == "Country or region") {
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
    
       if(input$country_region$CRS$code != 4326){
        geo_data_sf <- st_transform(geo_data_sf, crs_input)
    }
    print(st_crs(geo_data_sf))

    st_write(geo_data_sf, polygon_path)
}

if (input$polygon_type == "WDPA") {
    # adding quotes around it for duckdb functions

    con <- dbConnect(duckdb())

    dbExecute(con, "INSTALL spatial; LOAD spatial; INSTALL httpfs; LOAD httpfs;")
    dbExecute(con, 'CREATE OR REPLACE VIEW wdpa AS
    SELECT * FROM read_parquet("https://object-arbutus.cloud.computecanada.ca/bq-io/vectors-cloud/wdpa/wdpa.parquet")')

    if (!is.null(input$country_region$region$regionName)) {
        dbExecute(con, paste0("CREATE OR REPLACE TABLE region AS
        SELECT *
        FROM 'https://data.fieldmaps.io/edge-matched/humanitarian/intl/adm1_polygons.parquet'
        WHERE adm0_src='", input$country_region$country$ISO3, "' and adm1_name='", input$country_region$region$regionName, "'"))
    } else {
        dbExecute(con, paste0("CREATE OR REPLACE TABLE region AS SELECT *
        FROM 'https://data.fieldmaps.io/adm0/osm/intl/adm0_polygons.parquet' WHERE adm0_src='", input$country_region$country$ISO3, "'"))
    }


    # Transform region to crs of interest
    dbExecute(con, paste0("CREATE OR REPLACE TABLE region_crs AS
    SELECT * EXCLUDE geometry, ST_Transform(geometry, 'EPSG:4326', '", crs_input, "') AS geometry FROM region"))

    # buffer region
    dbExecute(con, paste0("
    CREATE OR REPLACE TABLE buffered_region AS
    SELECT ST_Buffer(geometry, ", input$buffer, ") AS geometry
    FROM region_crs
    "))

    # transform bbox of buffered region back to 4326 to filter wdpa data
    dbExecute(con, paste0("
    CREATE OR REPLACE TABLE bbox_filter AS
    SELECT
        ST_Transform(ST_Envelope(geometry), '", crs_input, "', 'EPSG:4326') AS geom_4326
    FROM buffered_region
"))


    # Filter WDPA and transform to the crs of interest
    dbExecute(con, paste0("
    CREATE OR REPLACE TABLE wdpa_filtered AS
    SELECT w.*
    FROM wdpa w, bbox_filter b
    WHERE w.bbox.xmax >= ST_XMin(b.geom_4326)
      AND w.bbox.xmin <= ST_XMax(b.geom_4326)
      AND w.bbox.ymax >= ST_YMin(b.geom_4326)
      AND w.bbox.ymin <= ST_YMax(b.geom_4326)
"))

    df <- dbGetQuery(con, paste0("SELECT w.*, 
    ST_AsWKB(ST_Transform(w.geometry, 'EPSG:4326', '", crs_input, "', TRUE)) as geometry_wkb
    FROM wdpa_filtered w, buffered_region b
     WHERE ST_Intersects(ST_Transform(w.geometry, 'EPSG:4326', '", crs_input, "'), b.geometry)"))

    print("row_count")
    print(nrow(df))
    df$geometry = sf::st_as_sfc(structure(as.list(df$geometry_wkb), class = "WKB"),crs = crs_input)
    st_write(df, polygon_path, delete_dsn = TRUE)
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
    if(input$country_region$CRS$code != 4326){
        geo_data_sf <- st_transform(geo_data_sf, crs_input)
    }

    st_write(geo_data_sf, polygon_path)
}

biab_output("polygon", polygon_path)
