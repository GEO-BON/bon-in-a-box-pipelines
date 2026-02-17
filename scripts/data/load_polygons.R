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

# Parquet URLS for polygons
countries_url <- "https://data.fieldmaps.io/adm0/osm/intl/adm0_polygons.parquet"
regions_url <- "https://data.fieldmaps.io/edge-matched/humanitarian/intl/adm1_polygons.parquet"
wdpa_url <- "https://object-arbutus.cloud.computecanada.ca/bq-io/vectors-cloud/wdpa/wdpa.parquet"
eez_url <- "https://object-arbutus.cloud.computecanada.ca/bq-io/vectors-cloud/marine_regions_eez/eez_v12.parquet"


crs_input <- paste0(input$country_region_bbox$CRS$authority, ":", input$country_region_bbox$CRS$code)
print(crs_input)
polygon_path <- file.path(outputFolder, "polygon.gpkg")
# Checks if crs is lat long
latlong <- st_is_longlat(st_crs(crs_input))

# Checks whether we have a custom bbox or not
# Robustly detect missing country: treat NULL, zero-length, and atomic NA as missing
val_country <- input$country_region_bbox$country
print(val_country)
country <- FALSE
if (!is.null(val_country) && length(val_country) > 0 && !(is.atomic(val_country) && all(is.na(val_country)))) {
    country <- TRUE
}

if (!country) {
    print("No country selected, will load polygon based on custom bounding box")
    bbox_values <- unlist(input$country_region_bbox$bbox)
    print(bbox_values)

    bbox_sf <- sf::st_as_sfc(
        sf::st_bbox(
            c(
                xmin = bbox_values[1],
                ymin = bbox_values[2],
                xmax = bbox_values[3],
                ymax = bbox_values[4]
            ),
            crs = crs_input
        )
    )
    if (!latlong) {
        bbox_sf_4326 <- sf::st_transform(bbox_sf, 4326) # transform bbox if not in 4326
    } else {
        bbox_sf_4326 <- bbox_sf
    }
    bbox_wkt_4326 <- sf::st_as_text(bbox_sf_4326)
    print(bbox_wkt_4326)
}

# Load country region polygon
if (input$polygon_type == "Country or region") {
    if (country) {
        # Load country if region is null
        if (is.null(input$country_region_bbox$region)) {
            print(sprintf("Loading country polygon for: %s", input$country_region_bbox$country$englishName))
            country_poly <- open_dataset(countries_url)
            geo_data_sf <- country_poly |>
                filter(adm0_src == input$country_region_bbox$country$ISO3) |>
                to_sf() |>
                st_set_crs(4326)
        } else { # Region not null
            print(sprintf("Loading region polygon for: %s", input$country_region_bbox$region$regionName))
            country_region_bbox <- open_dataset(regions_url)
            geo_data_sf <- country_region_bbox |>
                filter(adm0_src == input$country_region_bbox$country$ISO3) |>
                filter(adm1_name == input$country_region_bbox$region$regionName) |>
                to_sf() |>
                st_set_crs(4326)
            geo_data_sf$fid <- as.integer(geo_data_sf$fid)
        }
    } else { # custom bounding box
        print(sprintf("Loading region polygon for custom bounding box: %s", paste(input$country_region_bbox$bbox, collapse = ", ")))
        con <- dbConnect(duckdb())
        dbExecute(con, "INSTALL spatial; LOAD spatial; INSTALL httpfs; LOAD httpfs;")

        dbExecute(con, paste0("CREATE OR REPLACE VIEW bbox_view AS SELECT ST_GeomFromText('", bbox_wkt_4326, "') AS geom_4326"))


        dbExecute(con, paste0("
    CREATE OR REPLACE TABLE regions_filtered AS
    SELECT w.* FROM read_parquet('", regions_url, "') w, bbox_view b
    WHERE ST_Within(w.geometry, b.geom_4326)
    "))

        result_count <- dbGetQuery(con, "SELECT COUNT(*) as count FROM regions_filtered")

        # output as a sf object
        df <- dbGetQuery(con, "SELECT *, ST_AsWKB(geometry) AS geometry_wkb FROM regions_filtered")

        df$geometry <- sf::st_as_sfc(structure(as.list(df$geometry_wkb), class = "WKB"), crs = 4326)
        geo_data_sf <- st_as_sf(df)
        print("printing sf object")
        print(geo_data_sf)
    }


    if (input$country_region_bbox$CRS$code != 4326) {
        geo_data_sf <- st_transform(geo_data_sf, st_crs(crs_input))
    }

    print(st_crs(geo_data_sf))
    print(geo_data_sf)
    if ("fid" %in% names(geo_data_sf)) {
        geo_data_sf$fid <- as.integer(geo_data_sf$fid)
    }

    if (nrow(geo_data_sf) == 0) {
        biab_error_stop("There is no country or region polygon for this bounding box")
    }
    st_write(geo_data_sf, polygon_path)
}






############ WDPA #############

if (input$polygon_type == "WDPA") {
    # adding quotes around it for duckdb functions
    con <- dbConnect(duckdb())

    dbExecute(con, "INSTALL spatial; LOAD spatial; INSTALL httpfs; LOAD httpfs;")
    dbExecute(con, paste0("CREATE OR REPLACE VIEW wdpa AS
    SELECT * FROM read_parquet('", wdpa_url, "')"))

    # If user selected a country, we will use its polygon to crop the WDPA data
    if (country) {
        if (!is.null(input$country_region_bbox$region$regionName)) {
            print(sprintf("Loading WDPA data for: %s", input$country_region_bbox$region$regionName))
            dbExecute(con, paste0("CREATE OR REPLACE TABLE region AS
            SELECT *
            FROM read_parquet('", regions_url, "')
            WHERE adm0_src='", input$country_region_bbox$country$ISO3, "' and adm1_name='", input$country_region_bbox$region$regionName, "'"))
            
            # Check if region table was created successfully
            if (dbExistsTable(con, 'region')) {
                region_count <- dbGetQuery(con, "SELECT COUNT(*) as count FROM region")
                print(sprintf('Table region created successfully with %d rows', region_count$count))
            } else {
                print('Error: Table region was not created')
            }
        } else {
            print(sprintf("Loading WDPA for: %s", input$country_region_bbox$country$englishName))
            dbExecute(con, paste0("CREATE OR REPLACE TABLE region AS SELECT *
            FROM read_parquet('", countries_url, "') WHERE adm0_src='", input$country_region_bbox$country$ISO3, "'"))
            
            # Check if region table was created successfully
            if (dbExistsTable(con, 'region')) {
                region_count <- dbGetQuery(con, "SELECT COUNT(*) as count FROM region")
                print(sprintf('Table region created successfully with %d rows', region_count$count))
            } else {
                print('Error: Table region was not created')
            }
        }

        # If not in 4326: Transform region to crs of interest
        if (!latlong) {
            dbExecute(con, paste0("CREATE OR REPLACE TABLE region_crs AS
            SELECT * EXCLUDE geometry, ST_Transform(geometry, CAST('EPSG:4326' AS VARCHAR), CAST('", crs_input, "' AS VARCHAR)) AS geometry FROM region"))
        } else {
            dbExecute(con, "CREATE OR REPLACE TABLE region_crs AS SELECT * FROM region")
        }
        
        # Check if region_crs table was created successfully
        if (dbExistsTable(con, 'region_crs')) {
            region_crs_count <- dbGetQuery(con, "SELECT COUNT(*) as count FROM region_crs")
            print(sprintf('Table region_crs created successfully with %d rows', region_crs_count$count))
        } else {
            print('Error: Table region_crs was not created')
        }

      #  buffer region
        dbExecute(con, paste0("
        CREATE OR REPLACE TABLE buffered_region AS
        SELECT ST_Buffer(geometry, ", input$buffer, ") AS geometry
        FROM region_crs
        "))
        
        #Check if buffered_region table was created successfully
        if (dbExistsTable(con, 'buffered_region')) {
            buffered_region_count <- dbGetQuery(con, "SELECT COUNT(*) as count FROM buffered_region")
            print(sprintf('Table buffered_region created successfully with %d rows', buffered_region_count$count))            
            # Debug: Check the buffered_region geometry before envelope
            buffered_debug <- dbGetQuery(con, "SELECT ST_AsText(geometry) as geom_text, ST_IsEmpty(geometry) as is_empty, ST_IsValid(geometry) as is_valid FROM buffered_region LIMIT 1")
            print("buffered_region geometry details:")
            print(buffered_debug)        } else {
            print('Error: Table buffered_region was not created')
        }

        # transform bbox of buffered region back to 4326 to filter wdpa data
        if (!latlong) {
            dbExecute(con, paste0("
            CREATE OR REPLACE TABLE bbox_filter AS
            SELECT
                ST_Transform(ST_Envelope(geometry), CAST('", crs_input, "' AS VARCHAR), CAST('EPSG:4326' AS VARCHAR)) AS geom_4326
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
        
        # Check if bbox_filter table was created successfully
        if (dbExistsTable(con, 'bbox_filter')) {
            bbox_filter_count <- dbGetQuery(con, "SELECT COUNT(*) as count FROM bbox_filter")
            print(sprintf('Table bbox_filter created successfully with %d rows', bbox_filter_count$count))
            
            # Print bbox_filter geometry details
            bbox_filter_data <- dbGetQuery(con, "SELECT ST_AsText(geom_4326) as geom_text, ST_IsEmpty(geom_4326) as is_empty, ST_GeometryType(geom_4326) as geom_type FROM bbox_filter")
            print("bbox_filter geometry details:")
            print(bbox_filter_data)
        } else {
            print('Error: Table bbox_filter was not created')
        }

        # Filter WDPA and transform to the crs of interest
        dbExecute(con, paste0("
        CREATE OR REPLACE TABLE wdpa_filtered AS
        SELECT w.*
        FROM wdpa w, bbox_filter b
        WHERE ST_Intersects(w.geometry, b.geom_4326)
        "))
        
      #  Check if wdpa_filtered table was created successfully
        if (dbExistsTable(con, 'wdpa_filtered')) {
            wdpa_filtered_count <- dbGetQuery(con, "SELECT COUNT(*) as count FROM wdpa_filtered")
            print(sprintf('Table wdpa_filtered created successfully with %d rows', wdpa_filtered_count$count))
        } else {
            print('Error: Table wdpa_filtered was not created')
        }

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

        # print("row_count")
        # print(nrow(df))
        
        # # Check if df has data
        # if (nrow(df) == 0) {
        #     print("Warning: wdpa_filtered query returned 0 rows")
        # } else {
        #     print(sprintf("Successfully retrieved %d WDPA records", nrow(df)))
        # }
        
        df$geometry <- sf::st_as_sfc(structure(as.list(df$geometry_wkb), class = "WKB"), crs = st_crs(crs_input))
    } else {
        sprintf("Loading region WDPA data for custom bounding box: %s", input$country_region_bbox$bbox)
        bbox_values <- input$country_region_bbox$bbox
        names(bbox_values) <- c("xmin", "ymin", "xmax", "ymax")


        # Create bbox_filter table directly
        dbExecute(con, paste0("
        CREATE OR REPLACE TABLE bbox_filter AS
        SELECT ST_GeomFromText('", bbox_wkt_4326, "') AS geom_4326
        "))


        dbExecute(con, "
            CREATE OR REPLACE TABLE wdpa_filtered AS
            SELECT w.*
            FROM wdpa w
            JOIN bbox_filter b
            ON ST_Intersects(w.geometry, b.geom_4326)
        ")

        # Convert geometry to WKB and then sf
        df <- dbGetQuery(con, "
            SELECT *, ST_AsWKB(geometry) AS geometry_wkb
            FROM wdpa_filtered
        ")
        df$geometry <- sf::st_as_sfc(structure(as.list(df$geometry_wkb), class = "WKB"), crs = 4326)
    }

    # ensure df is an sf object before writing
    df_sf <- st_as_sf(df)

    if ("fid" %in% names(df_sf)) {
        df_sf$fid <- as.integer(df_sf$fid)
    }

    if (nrow(df_sf) == 0) {
        biab_error_stop("There is no WDPA data for this country or bounding box")
    }

    st_write(df_sf, polygon_path, delete_dsn = TRUE)
}





################# EEZ #################
if (input$polygon_type == "EEZ") {
    if (country) { # Filter by country name
        eez <- open_dataset(eez_url)
        print(sprintf("Loading EEZ for: %s", input$country_region_bbox$englishName))
        ISO3 <- substr(input$country_region_bbox$country$ISO3, 1, 3)
        print(ISO3)
        geo_data_sf <- eez |>
            filter(ISO_TER1 == ISO3) |>
            to_sf() |>
            st_set_crs(4326)
    } else { # Filter by custom bounding box
        print("Loading EEZ based on custom bounding box:")

        con <- dbConnect(duckdb())
        dbExecute(con, "INSTALL spatial; LOAD spatial; INSTALL httpfs; LOAD httpfs;")

        dbExecute(con, paste0("CREATE OR REPLACE VIEW bbox_view AS SELECT ST_GeomFromText('", bbox_wkt_4326, "') AS geom_4326"))

        dbExecute(con, paste0("
        CREATE OR REPLACE TABLE eez_filtered AS
        SELECT w.* EXCLUDE (geom), w.geom AS geometry
        FROM read_parquet('", eez_url, "') w, bbox_view b
        WHERE ST_Intersects(w.geom, b.geom_4326)
        "))
        # output as a sf object
        df <- dbGetQuery(con, "SELECT *, ST_AsWKB(geometry) AS geometry_wkb FROM eez_filtered")
        df$geometry <- sf::st_as_sfc(structure(as.list(df$geometry_wkb), class = "WKB"), crs = 4326)
        geo_data_sf <- st_as_sf(df)
    }

    if ("fid" %in% names(geo_data_sf)) {
        geo_data_sf$fid <- as.integer(geo_data_sf$fid)
    }


    if (nrow(geo_data_sf) == 0) {
        biab_error_stop("There is no Exclusive Economic Zone for this country or bounding box")
    }
    if (input$country_region_bbox$CRS$code != 4326) {
        geo_data_sf <- st_transform(geo_data_sf, st_crs(crs_input))
    }
    st_write(geo_data_sf, polygon_path)
}

biab_output("polygon", polygon_path)
