library(duckdb)
library(sf)

Sys.setenv(HOME = "/output")

input <- biab_inputs()

# Parquet URLS for polygons
countries_url <- "https://data.fieldmaps.io/adm0/osm/intl/adm0_polygons.parquet"
regions_url <- "https://data.fieldmaps.io/edge-matched/humanitarian/intl/adm1_polygons.parquet"
wdpa_url <- "https://object-arbutus.alliancecan.ca/3857940e33774dca8ae21e4999fe402e:vectors-cloud/wdpa/wdpa_oct2026.parquet"
eez_url <- "https://object-arbutus.alliancecan.ca/3857940e33774dca8ae21e4999fe402e:vectors-cloud/marine_regions_eez/eez_v12.parquet"


crs_input <- paste0(input$country_region_bbox$CRS$authority, ":", input$country_region_bbox$CRS$code)
print(crs_input)

# Checks whether we have a custom bbox or not
# Robustly detect missing country: treat NULL, zero-length, and atomic NA as missing
val_country <- input$country_region_bbox$country
print(val_country)
country <- FALSE
if (!is.null(val_country) && length(val_country) > 0 && !(is.atomic(val_country) && all(is.na(val_country)))) {
    country <- TRUE
}
region <- country && !is.null(input$country_region_bbox$region)

# Path for polygon
if (country) { # if there is a country or region input
    if (!region) {
        name <- gsub(" ", "_", input$country_region_bbox$country$englishName)
    } else {
        name <- gsub(" ", "_", input$country_region_bbox$region$regionName)
    }
} else {
    name <- "bbox" # or we just call it bbox
}

if (input$polygon_type == "Country or region") {
    polygon_path <- file.path(outputFolder, paste0(name, "_polygon.gpkg"))
} else if (input$polygon_type == "Polygon of bounding box") {
    polygon_path <- file.path(outputFolder, paste0("bbox_polygon.gpkg"))
} else {
    polygon_path <- file.path(outputFolder, paste0(input$polygon_type, "_", name, "_polygon.gpkg"))
}

con <- dbConnect(duckdb())
dbExecute(con, "INSTALL spatial; LOAD spatial; INSTALL httpfs; LOAD httpfs;")
dbExecute(con, "SET geometry_always_xy = true") # lon/lat axis order for EPSG:4326

# SQL envelope of the custom bbox, in the input CRS
bbox_envelope <- function() {
    bbox_values <- unlist(input$country_region_bbox$bbox)
    if (is.null(bbox_values) || length(bbox_values) != 4 || any(is.na(bbox_values))) {
        biab_error_stop("A valid bbox with four coordinates is required when no country ISO3 is supplied or when polygon type is 'Polygon of bounding box'.")
    }
    print(sprintf("Using bounding box: %s", paste(bbox_values, collapse = ", ")))
    sprintf("ST_MakeEnvelope(%s)", paste(format(bbox_values, scientific = FALSE), collapse = ", "))
}

# Same envelope, in EPSG:4326
bbox_envelope_4326 <- function() {
    sprintf("ST_Transform(%s, '%s', 'EPSG:4326')", bbox_envelope(), crs_input)
}

# SQL selecting the country or region polygon, with geometry in a column named geom
country_region_sql <- function() {
    iso3 <- dbQuoteString(con, input$country_region_bbox$country$ISO3)
    if (!region) {
        print(sprintf("Loading country polygon for: %s", input$country_region_bbox$country$englishName))
        sprintf("SELECT * RENAME (geometry AS geom) FROM read_parquet('%s') WHERE adm0_src = %s", countries_url, iso3)
    } else {
        print(sprintf("Loading region polygon for: %s", input$country_region_bbox$region$regionName))
        sprintf(
            "SELECT * RENAME (geometry AS geom) FROM read_parquet('%s') WHERE adm0_src = %s AND adm1_name = %s",
            regions_url, iso3, dbQuoteString(con, input$country_region_bbox$region$regionName)
        )
    }
}

# Writes the result of a query to polygon_path in the input CRS.
# The query must return its geometry in a column named geom, in source_crs.
write_polygons <- function(sql, empty_message, source_crs = "EPSG:4326") {
    dbExecute(con, paste("CREATE OR REPLACE TABLE result AS", sql))

    n <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM result")$n
    print(sprintf("%d polygons found", n))
    if (n == 0) {
        biab_error_stop(empty_message)
    }

    # GPKG can't store structs (parquet bbox columns) and manages its own fid
    cols <- dbGetQuery(con, "DESCRIBE result")
    keep <- cols$column_name[!grepl("^STRUCT", cols$column_type) & !tolower(cols$column_name) %in% c("fid", "ogc_fid", "geom")]
    geom <- if (source_crs == crs_input) "geom" else sprintf("ST_Transform(geom, '%s', '%s')", source_crs, crs_input)

    unlink(polygon_path)
    dbExecute(con, sprintf(
        "COPY (SELECT %s AS geom FROM result) TO '%s' WITH (FORMAT GDAL, DRIVER 'GPKG', SRS '%s', LAYER_NAME '%s')",
        paste(c(dbQuoteIdentifier(con, keep), geom), collapse = ", "),
        polygon_path, crs_input, tools::file_path_sans_ext(basename(polygon_path))
    ))
}


############ Country or region #############

if (input$polygon_type == "Country or region") {
    if (country) {
        sql <- country_region_sql()
    } else { # regions entirely within the custom bbox
        sql <- sprintf(
            "SELECT * RENAME (geometry AS geom) FROM read_parquet('%s') WHERE ST_Within(geometry, %s)",
            regions_url, bbox_envelope_4326()
        )
    }
    write_polygons(sql, "There is no country or region polygon for this bounding box")
}


############ WDPCA #############

if (input$polygon_type == "WDPCA") {
    # Make sure buffer distance is in the correct units
    buffer <- if (is.null(input$buffer)) 0 else input$buffer
    if (buffer > 0) {
        if (st_is_longlat(st_crs(crs_input)) && buffer > 1) {
            biab_error_stop("CRS is in degrees and buffer distance is in meters.")
        }
        if (!st_is_longlat(st_crs(crs_input)) && buffer < 1) {
            biab_error_stop("CRS is in meters and buffer distance is in degrees.")
        }
    }

    clip <- isTRUE(input$clip_to_location)
    if (clip && !country) {
        biab_error_stop("A country or region must be selected to clip to location.")
    }
    if (!country) {
        buffer <- 0 # buffer not applied to custom bbox
    }

    # Bounding box in EPSG:4326, expanded by the buffer in the input CRS
    bbox_geom <- bbox_envelope()
    if (buffer > 0) {
        bbox_geom <- sprintf("ST_Envelope(ST_Buffer(%s, %s))", bbox_geom, buffer)
    }
    dbExecute(con, sprintf("CREATE TABLE aoi AS SELECT ST_Transform(%s, '%s', 'EPSG:4326') AS geom", bbox_geom, crs_input))
    ext <- dbGetQuery(con, "SELECT ST_XMin(geom) xmin, ST_YMin(geom) ymin, ST_XMax(geom) xmax, ST_YMax(geom) ymax FROM aoi")

    # Optionally keep only PAs touching the (buffered) country or region
    location_join <- ""
    location_filter <- ""
    if (clip) {
        location_geom <- "ST_Union_Agg(geom)"
        if (buffer > 0) {
            location_geom <- sprintf(
                "ST_Transform(ST_Buffer(ST_Transform(%s, 'EPSG:4326', '%s'), %s), '%s', 'EPSG:4326')",
                location_geom, crs_input, buffer, crs_input
            )
        }
        dbExecute(con, sprintf("CREATE TABLE location AS SELECT %s AS geom FROM (%s)", location_geom, country_region_sql()))
        if (is.na(dbGetQuery(con, "SELECT ST_IsEmpty(geom) AS e FROM location")$e)) {
            biab_error_stop("Could not find a polygon for this country or region")
        }
        location_join <- ", location l"
        location_filter <- "AND ST_Intersects(w.geom, l.geom)"
    }

    # Pre-filter on WDPA bbox column (parquet stats pushdown), then exact intersection
    write_polygons(
        sprintf("
            SELECT w.*
            FROM read_parquet('%s') w, aoi a %s
            WHERE w.bbox.xmax >= %f AND w.bbox.xmin <= %f AND w.bbox.ymax >= %f AND w.bbox.ymin <= %f
              AND ST_Intersects(w.geom, a.geom) %s",
            wdpa_url, location_join, ext$xmin, ext$xmax, ext$ymin, ext$ymax, location_filter
        ),
        "There is no WDPA data for this country or bounding box"
    )
}


################# EEZ #################

if (input$polygon_type == "EEZ") {
    if (country) { # Filter by country (regions are ignored for EEZs)
        print(sprintf("Loading EEZ for: %s", input$country_region_bbox$country$englishName))
        iso3 <- dbQuoteString(con, substr(input$country_region_bbox$country$ISO3, 1, 3))
        sql <- sprintf("SELECT * FROM read_parquet('%s') WHERE ISO_TER1 = %s", eez_url, iso3)
    } else {
        sql <- sprintf("SELECT * FROM read_parquet('%s') WHERE ST_Intersects(geom, %s)", eez_url, bbox_envelope_4326())
    }
    write_polygons(sql, "There is no Exclusive Economic Zone for this country or bounding box")
}


############ Polygon of bounding box #############

if (input$polygon_type == "Polygon of bounding box") {
    write_polygons(sprintf("SELECT %s AS geom", bbox_envelope()), "Invalid bounding box", source_crs = crs_input)
}

dbDisconnect(con, shutdown = TRUE)

biab_output("polygon", polygon_path)
biab_output("bbox_crs", input$country_region_bbox)
