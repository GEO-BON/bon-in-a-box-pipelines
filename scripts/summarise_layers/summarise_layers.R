library(gdalcubes)
library(terra)

input <- biab_inputs()

# Accept LAI rasters from calculateLAI output handle; keep fallback for legacy wiring.
raster_paths <- input$lai_layers

if (is.null(raster_paths) || length(raster_paths) == 0) {
  raster_paths <- input$rasters
}

if (is.null(raster_paths) || length(raster_paths) == 0) {
  biab_error_stop("No LAI raster input found. Connect calculateLAI output 'rasters' to input 'lai_layers'.")
}

target_crs <- paste0(input$bbox_crs$CRS$authority, ":", input$bbox_crs$CRS$code)
bbox <- input$bbox_crs$bbox
if (is.null(bbox) || length(bbox) != 4) {
  biab_error_stop("bbox_crs must contain a valid bbox with 4 coordinates.")
}

spatial_resolution <- input$spatial_resolution
if (is.null(spatial_resolution) || identical(spatial_resolution, "")) {
  spatial_resolution <- NA_real_
} else {
  spatial_resolution <- as.numeric(spatial_resolution)
}

parse_date_from_path <- function(p) {
  name <- basename(p)

  # First try explicit date patterns in filename.
  m <- regmatches(name, regexpr("[0-9]{4}[-_][0-9]{2}[-_][0-9]{2}", name))
  if (length(m) == 1 && m != "") {
    return(as.character(as.Date(gsub("_", "-", m))))
  }

  # Fallback to year-only pattern in filename.
  y <- regmatches(name, regexpr("(19|20)[0-9]{2}", name))
  if (length(y) == 1 && y != "") {
    return(paste0(y, "-01-01"))
  }

  NA_character_
}

normalise_input_date <- function(x, is_end = FALSE) {
  if (is.null(x) || identical(x, "")) {
    return(NA_character_)
  }

  x <- as.character(x)
  if (grepl("^[0-9]{4}$", x)) {
    if (is_end) {
      return(paste0(x, "-12-31"))
    }
    return(paste0(x, "-01-01"))
  }

  if (grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", x)) {
    return(x)
  }

  NA_character_
}

start_date <- normalise_input_date(input$start_year, is_end = FALSE)
end_date <- normalise_input_date(input$end_year, is_end = TRUE)

date_time <- rep(NA_character_, length(raster_paths))

print(paste("start_date:", start_date))
print(paste("end_date:", end_date))
print(paste("date_time:", paste(date_time, collapse = ", ")))

# Prefer the same date inputs as calculateLAI when they match layer count.
if (!is.na(start_date) && !is.na(end_date)) {
  seq_dates <- seq.Date(as.Date(start_date), as.Date(end_date), by = "year")
  if (length(seq_dates) == length(raster_paths)) {
    date_time <- as.character(seq_dates)
  } else {
    biab_warning("start_year/end_year do not match number of LAI layers; falling back to dates parsed from rasters.")
  }
}

print(paste("date_time after start/end year check:", paste(date_time, collapse = ", ")))

if (any(is.na(date_time))) {
  date_time <- vapply(raster_paths, parse_date_from_path, character(1))
}

print(paste("date_time after parsing from raster paths:", paste(date_time, collapse = ", ")))


col <- gdalcubes::create_image_collection(
  files = raster_paths,
  date_time = date_time,
  band_names = "LAI"
)


if (is.na(spatial_resolution)) {
  native_res <- terra::res(terra::rast(raster_paths[1]))
  dx <- native_res[1]
  dy <- native_res[2]
} else {
  dx <- spatial_resolution
  dy <- spatial_resolution
}

print(paste("dx:", dx, "dy:", dy))
print(paste("spatial resolution:", spatial_resolution))

v <- gdalcubes::cube_view(
  extent = list(
    left = bbox[1],
    right = bbox[3],
    bottom = bbox[2],
    top = bbox[4],
    t0 = min(date_time),
    t1 = max(date_time)
  ),
  srs = target_crs,
  dx = dx,
  dy = dy,
  dt = "P1Y",
  resampling = "bilinear",
  aggregation = "min"
)

print(min(date_time))
print(max(date_time))

cube <- gdalcubes::raster_cube(col, v)

# One output layer: max LAI per pixel across all temporal layers.
cube_summary <- gdalcubes::reduce_time(cube, "min(LAI)")

print(cube_summary)

out <- gdalcubes::write_tif(
  cube_summary,
  dir = outputFolder,
  prefix = "lai_min_over_time_",
  creation_options = list("COMPRESS" = "DEFLATE"),
  COG = TRUE,
  write_json_descr = TRUE
)

biab_output("rasters", out)