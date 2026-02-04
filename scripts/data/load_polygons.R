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

crs_input <- paste0(input$country_region_bbox$CRS$authority, ":", input$country_region_bbox$CRS$code)
polygon_path <- file.path(outputFolder, "polygon.gpkg")

# Checks if crs is lat long
latlong <- st_is_longlat(crs_input)

# Checks whether we have a custom bbox or not
if (is.null(input$country_region_bbox$country)) {
    country <- FALSE
} else {
    country <- TRUE
}

# Load country region polygon
if (input$polygon_type == "Country or region") {
    if (country) {
        # Load country if region is null
        if (is.null(input$country_region_bbox$region)) {
            sprintf("Loading country polygon for: %s", input$country_region_bbox$country$englishName)
            country_poly <- open_dataset("https://data.fieldmaps.io/adm0/osm/intl/adm0_polygons.parquet")
            geo_data_sf <- country_poly |>
                filter(adm0_src == input$country_region_bbox$country$ISO3) |>
                to_sf() |>
                st_set_crs(4326)

        } else { # Region not null
            sprintf("Loading region polygon for: %s", input$country_region_bbox$region$regionName)
            country_region_bbox <- open_dataset("https://data.fieldmaps.io/edge-matched/humanitarian/intl/adm1_polygons.parquet")
            geo_data_sf <- country_region_bbox |>
                filter(adm0_src == input$country_region_bbox$country$ISO3) |>
                filter(adm1_name == input$country_region_bbox$region$regionName) |>
                to_sf() |>
                st_set_crs(4326)
            geo_data_sf$fid <- as.integer(geo_data_sf$fid)
        }
    } else { # custom bounding box
        sprintf("Loading region polygon for custom bounding box: %s", input$country_region_bbox$bbox)
        bbox_values <- (input$country_region_bbox$bbox)
        names(bbox_values) <- c("xmin", "ymin", "xmax", "ymax")
        geo_data_sf <- st_as_sfc(st_bbox(bbox_values, crs = crs_input)) ### need to assign CRS
        # transform back to 4326 if not already NEED TO DO THIS
    }

    if (input$country_region_bbox$CRS$code != 4326) {
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

    # If user selected a country, we will use its polygon to crop the WDPA data
    if (country) {
        if (!is.null(input$country_region_bbox_bbox$region$regionName)) {
            dbExecute(con, paste0("CREATE OR REPLACE TABLE region AS
            SELECT *
            FROM 'https://data.fieldmaps.io/edge-matched/humanitarian/intl/adm1_polygons.parquet'
            WHERE adm0_src='", input$country_region_bbox$country$ISO3, "' and adm1_name='", input$country_region_bbox$region$regionName, "'"))
        } else {
            dbExecute(con, paste0("CREATE OR REPLACE TABLE region AS SELECT *
            FROM 'https://data.fieldmaps.io/adm0/osm/intl/adm0_polygons.parquet' WHERE adm0_src='", input$country_region_bbox$country$ISO3, "'"))
        }

        # If not in 4326: Transform region to crs of interest
        if (!latlong) {
            dbExecute(con, paste0("CREATE OR REPLACE TABLE region_crs AS
            SELECT * EXCLUDE geometry, ST_Transform(geometry, 'EPSG:4326', '", crs_input, "') AS geometry FROM region"))
        } else {
           dbExecute(con, "CREATE OR REPLACE TABLE region_crs AS SELECT * FROM region")
        }
        print("here")
        print(dbGetQuery(con, "SELECT * FROM region_crs LIMIT 5"))

        # buffer region
        dbExecute(con, paste0("
        CREATE OR REPLACE TABLE buffered_region AS
        SELECT ST_Buffer(geometry, ", input$buffer, ") AS geometry
        FROM region_crs
        "))

        # transform bbox of buffered region back to 4326 to filter wdpa data
        if (!latlong) {
            dbExecute(con, paste0("
            CREATE OR REPLACE TABLE bbox_filter AS
            SELECT
                ST_Transform(ST_Envelope(geometry), '", crs_input, "', 'EPSG:4326') AS geom_4326
            FROM buffered_region
            "))
        } else {
            dbExecute(con, paste0("
            CREATE OR REPLACE TABLE bbox_filter AS
            SELECT
                ST_Envelope(geometry) AS geom_4326
            FROM buffered_region
            "))
        }

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

        if (!latlong) {
            df <- dbGetQuery(con, paste0("SELECT w.*,
            ST_AsWKB(ST_Transform(w.geometry, 'EPSG:4326', '", crs_input, "', TRUE)) as geometry_wkb
            FROM wdpa_filtered w, buffered_region b
            WHERE ST_Intersects(ST_Transform(w.geometry, 'EPSG:4326', '", crs_input, "'), b.geometry)"))
        } else {
            df <- dbGetQuery(con, paste0("SELECT w.*,
            ST_AsWKB(w.geometry) as geometry_wkb
            FROM wdpa_filtered w, buffered_region b
            WHERE ST_Intersects(w.geometry, b.geometry)"))
        }

        print("row_count")
        print(nrow(df))
        df$geometry <- sf::st_as_sfc(structure(as.list(df$geometry_wkb), class = "WKB"), crs = crs_input)
    } else {
        bbox_values <- input$bbox_crs$bbox
        names(bbox_values) <- c("xmin", "ymin", "xmax", "ymax")

        # Convert to WKT polygon for DuckDB
        bbox_wkt <- paste0(
            "POLYGON((",
            bbox_values["xmin"], " ", bbox_values["ymin"], ", ",
            bbox_values["xmin"], " ", bbox_values["ymax"], ", ",
            bbox_values["xmax"], " ", bbox_values["ymax"], ", ",
            bbox_values["xmax"], " ", bbox_values["ymin"], ", ",
            bbox_values["xmin"], " ", bbox_values["ymin"],
            "))"
        )
        # Create bbox_filter table directly
        dbExecute(con, paste0("
            CREATE OR REPLACE TABLE bbox_filter AS
            SELECT ST_GeomFromText('", bbox_wkt, "', 4326) AS geom_4326
        "))
            # Filter WDPA based on bbox
        dbExecute(con, "
            CREATE OR REPLACE TABLE wdpa_filtered AS
            SELECT w.*
            FROM wdpa w, bbox_filter b
            WHERE w.bbox.xmax >= ST_XMin(b.geom_4326)
            AND w.bbox.xmin <= ST_XMax(b.geom_4326)
            AND w.bbox.ymax >= ST_YMin(b.geom_4326)
            AND w.bbox.ymin <= ST_YMax(b.geom_4326)
        ")

        # Convert geometry to WKB and then sf
        df <- dbGetQuery(con, "
            SELECT *, ST_AsWKB(geometry) AS geometry_wkb
            FROM wdpa_filtered
        ")
        df$geometry <- sf::st_as_sfc(structure(as.list(df$geometry_wkb), class = "WKB"), crs = 4326)
    }
    st_write(df, polygon_path, delete_dsn = TRUE)
}


if (input$polygon_type == "EEZ") {
    if (country) { # Filter by country name
        eez <- open_dataset("https://object-arbutus.cloud.computecanada.ca/bq-io/vectors-cloud/marine_regions_eez/eez_v12.parquet")
        sprintf("Loading EEZ for: %s", input$country_region_bbox$englishName)

        geo_data_sf <- eez |>
            filter(TERRITORY1 == input$country_region_bbox$country$englishName) |>
            to_sf() |>
            st_set_crs(4326)
    } else { # Filter by custom bounding box
        bbox <- input$country_region_bbox$bbox
        print("Loading EEZ based on custom bounding box:")
        print(bbox)

        bbox_sf <- st_as_sfc(
            st_bbox(
                c(
                xmin = bbox[1],
                ymin = bbox[2],
                xmax = bbox[3],
                ymax = bbox[4]
                ),
                crs = 4326
            )
        )
        eez <- open_dataset("https://object-arbutus.cloud.computecanada.ca/bq-io/vectors-cloud/marine_regions_eez/eez_v12.parquet")

        geo_data_sf <- eez |>
            to_sf() |>
            st_set_crs(4326) |>
            mutate(geom = st_make_valid(geom)) |>
            filter(st_intersects(geom, bbox_sf, sparse = FALSE))
    }
    geo_data_sf$fid <- as.integer(geo_data_sf$fid)

    if (nrow(geo_data_sf) == 0) {
        biab_error_stop("There is no Exclusive Economic Zone for this country")
    }
    if (input$country_region_bbox$CRS$code != 4326) {
        geo_data_sf <- st_transform(geo_data_sf, crs_input)
    }
    st_write(geo_data_sf, polygon_path)
}

biab_output("polygon", polygon_path)
