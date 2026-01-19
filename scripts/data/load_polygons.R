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
print(input$country_region)

crs_input <- paste0(input$country_region$CRS$authority, ":", input$country_region$CRS$code)
polygon_path <- file.path(outputFolder, "polygon.gpkg")
region_path <- file.path(outputFolder, "country_region.gpkg")
print(polygon_path)

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

    st_write(geo_data_sf, region_path)
}

if (input$polygon_type == "WDPA") {
    
    # adding quotes around it for duckdb functions
    crs_input <- paste0("'", crs_input, "'")
    print("crs:")
    print(crs_input)

    con <- dbConnect(duckdb())

    dbExecute(con, "INSTALL spatial; LOAD spatial; INSTALL httpfs; LOAD httpfs;")
    dbExecute(con, 'CREATE OR REPLACE VIEW wdpa AS
    SELECT * EXCLUDE geometry, geometry::GEOMETRY AS geometry FROM read_parquet("https://object-arbutus.cloud.computecanada.ca/bq-io/vectors-cloud/wdpa/wdpa.parquet")')

    if (!is.null(input$country_region$region$regionName)) {
        dbExecute(con, paste0("CREATE OR REPLACE TABLE region AS 
        SELECT * EXCLUDE geometry, geometry::GEOMETRY AS geometry
        FROM 'https://data.fieldmaps.io/edge-matched/humanitarian/intl/adm1_polygons.parquet' 
        WHERE adm0_src='", input$country_region$country$ISO3, "' and adm1_name='", input$country_region$region$regionName, "'"))
    } else {
        dbExecute(con, paste0("CREATE OR REPLACE TABLE region AS SELECT * EXCLUDE geometry, geometry::GEOMETRY AS geometry
        FROM 'https://data.fieldmaps.io/adm0/osm/intl/adm0_polygons.parquet' WHERE adm0_src='", input$country_region$country$ISO3, "'"))
    }
    
    # 4. Filter WDPA while everything is still in DEGREES (Crucial for BBox performance)
    dbExecute(con, paste0("CREATE OR REPLACE TABLE wdpa_region AS 
    SELECT 
        w.* EXCLUDE (geometry), 
        ST_Transform(w.geometry, 'EPSG:4326', ", crs_input, ") AS geometry
    FROM wdpa w, region r
    WHERE w.bbox.xmax >= ST_XMin(r.geometry) 
      AND w.bbox.xmin <= ST_XMax(r.geometry)
      AND w.bbox.ymax >= ST_YMin(r.geometry)
      AND w.bbox.ymin <= ST_YMax(r.geometry)
"))

    # 5. Transform Region and Buffer (Now we move to the projected CRS)
    dbExecute(con, paste0("CREATE OR REPLACE TABLE region AS 
    SELECT * EXCLUDE geometry, ST_Transform(geometry, 'EPSG:4326', ", crs_input, ") AS geometry FROM region"))

    dbExecute(con, paste0("
    CREATE OR REPLACE TABLE buffered_region AS 
    SELECT ST_Buffer(geometry, ", input$buffer, ") AS geometry
    FROM region
    "))
    
    # dbExecute(con, paste0("
    # CREATE OR REPLACE TABLE buffered_region AS
    # SELECT
    #     ST_Transform(
    #         ST_Buffer(
    #             ST_Transform(geometry, 'EPSG:4326',", crs_input,"), 
    #             ", input$buffer, "
    #         ),
    #         'EPSG:3857', 'EPSG:4326'
    #     ) AS geometry
    # FROM region
    # "))

# dbExecute(con, "CREATE OR REPLACE TABLE wdpa_region AS (
#     WITH b_reg AS (
#         SELECT 
#             ST_XMin(geometry) AS xmin_b, ST_YMin(geometry) AS ymin_b, 
#             ST_XMax(geometry) AS xmax_b, ST_YMax(geometry) AS ymax_b 
#         FROM buffered_region
#     )
#     SELECT w.* EXCLUDE (bbox)
#     FROM wdpa w, b_reg b
#     WHERE w.bbox.xmax >= b.xmin_b AND w.bbox.xmin <= b.xmax_b 
#       AND w.bbox.ymin <= b.ymax_b AND w.bbox.ymax >= b.ymin_b
# )")

dbExecute(con, paste0("CREATE OR REPLACE TABLE wdpa_region AS 
    SELECT 
        w.* EXCLUDE (geometry), 
        ST_Transform(w.geometry, 'EPSG:4326', ", crs_input, ") AS geometry
    FROM wdpa w, region r
    WHERE w.bbox.xmax >= ST_XMin(r.geometry) 
      AND w.bbox.xmin <= ST_XMax(r.geometry)
      AND w.bbox.ymax >= ST_YMin(r.geometry) 
    AND w.bbox.ymin <= ST_YMax(r.geometry)
"))

# 6. Final Spatial Join & Export
# This finds exactly what is inside the buffer

region_output <- dbExecute(con, "
   CREATE OR REPLACE TABLE region_output AS SELECT 
        w.* EXCLUDE (bbox) 
    FROM wdpa_region w, buffered_region b
    WHERE ST_Intersects(w.geometry, b.geometry)")


ddbs_read_vector(con, "region_output") |> st_set_crs(4326) |> st_transform(crs_input) |>
    st_write(polygon_path, delete_dsn = TRUE)
# dbExecute(con, paste0("COPY (
#     SELECT 
#         w.* EXCLUDE (bbox) 
#     FROM wdpa_region w, buffered_region b
#     WHERE ST_Intersects(w.geometry, b.geometry)
# ) TO '/", outputFolder, "/polygon.gpkg' (DRIVER 'GPKG', FORMAT gdal, SRS ", crs_input, ")"))
    # dbExecute(con, "CREATE OR REPLACE TABLE wdpa_region AS (WITH reg AS (
    #     SELECT
    #         geometry_bbox.xmin AS xmin_r,
    #         geometry_bbox.ymin AS ymin_r,
    #         geometry_bbox.xmax AS xmax_r,
    #         geometry_bbox.ymax AS ymax_r
    #     FROM region
    # )
    # SELECT w.* EXCLUDE(geom_wkt, bbox)
    # FROM wdpa w, reg r
    # WHERE
    #     bbox.xmax >= r.xmin_r AND
    #     bbox.xmin <= r.xmax_r AND
    #     bbox.ymin <= r.ymax_r AND
    #     bbox.ymax >= r.ymin_r)")

    # dbExecute(con, paste0("COPY (SELECT w.* FROM wdpa_region w, region r WHERE ST_DWithin(w.geometry,r.geometry, ", input$buffer, ")) TO '/", outputFolder, "/polygon.gpkg' (DRIVER 'GPKG', FORMAT gdal, SRS 'EPSG:4326')"))
    # polygon_path <- file.path(outputFolder, "polygon.gpkg")
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

    st_write(geo_data_sf, polygon_path)
}

biab_output("polygon", polygon_path)
