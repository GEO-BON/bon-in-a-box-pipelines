# Load the assets produced by the STAC chooser (stac_asset[]).
library(terra)

input <- biab_inputs()

has_text <- function(value) {
  is.character(value) && length(value) == 1L && !is.na(value) && nzchar(value)
}

if (is.null(input$stac) || length(input$stac) == 0L) {
  biab_error_stop("Please add at least one asset using the STAC chooser.")
}

# The runner may serialize each chooser object as a JSON string.
if (!is.list(input$stac) && !is.character(input$stac)) {
  biab_error_stop("The STAC chooser selections must be a list of objects or JSON strings.")
}
input$stac <- lapply(seq_along(input$stac), function(index) {
  selection <- input$stac[[index]]
  if (is.character(selection)) {
    selection <- tryCatch(rjson::fromJSON(selection), error = function(error) {
      biab_error_stop(paste0("STAC selection ", index, " contains invalid JSON: ", conditionMessage(error)))
    })
  }
  if (!is.list(selection) || is.null(names(selection))) {
    biab_error_stop(paste0("STAC selection ", index, " must be an object containing the selected asset details."))
  }
  selection
})

bbox <- unlist(input$bbox_crs$bbox, use.names = FALSE)
crs_info <- input$bbox_crs$CRS
if (length(bbox) != 4L || !is.numeric(bbox) || any(!is.finite(bbox)) ||
    !has_text(crs_info$authority) || is.null(crs_info$code)) {
  biab_error_stop("Please select a bounding box and CRS.")
}
if (bbox[1] >= bbox[3] || bbox[2] >= bbox[4]) {
  biab_error_stop("The bounding box must have left < right and bottom < top.")
}
target_crs <- paste0(crs_info$authority, ":", crs_info$code)
target_extent <- terra::ext(bbox[c(1, 3, 2, 4)])
resolution <- input$spatial_res
if (!is.null(resolution) &&
    (!is.numeric(resolution) || length(resolution) != 1L ||
     !is.finite(resolution) || resolution <= 0)) {
  biab_error_stop("Spatial resolution must be a positive number in the target CRS units.")
}

study_area <- NULL
if (has_text(input$study_area)) {
  study_area <- terra::project(terra::vect(input$study_area), target_crs)
}

# HTTP raster reads use GDAL's range requests rather than downloading whole files.
Sys.setenv(GDAL_DISABLE_READDIR_ON_OPEN = "EMPTY_DIR", VSI_CACHE = "TRUE")

read_asset <- function(href) {
  if (!has_text(href)) biab_error_stop("The selected STAC asset has no usable href.")
  path <- if (grepl("^https?://", href)) paste0("/vsicurl/", href) else href
  terra::rast(path)
}

selection_hrefs <- function(selection) {
  if (!isTRUE(selection$items_are_tiles)) {
    if (has_text(selection$href)) return(selection$href)
    if (!has_text(selection$item)) biab_error_stop("The selection is missing its STAC item.")
    item <- rstac::stac(selection$catalog) |>
      rstac::collections(selection$collection) |>
      rstac::items(selection$item) |>
      rstac::get_request()
    return(item$assets[[selection$asset]]$href)
  }

  # Collection endpoints work with both static catalogs and STAC APIs.
  items <- rstac::stac(selection$catalog) |>
    rstac::collections(selection$collection) |>
    rstac::items() |>
    rstac::get_request() |>
    rstac::items_fetch()
  features <- items$features
  item_day <- function(item) {
    date <- item$properties$datetime
    if (!has_text(date)) date <- item$properties$start_datetime
    if (has_text(date)) substr(date, 1L, 10L) else NA_character_
  }
  days <- vapply(features, item_day, character(1))
  if (has_text(selection$date)) {
    features <- features[!is.na(days) & days == selection$date]
  } else if (length(unique(days[!is.na(days)])) > 1L) {
    biab_error_stop("This tile collection spans multiple dates. Please choose one date in the STAC chooser.")
  }
  if (length(features) == 0L) {
    biab_error_stop("No STAC tiles were found for the selected collection and date.")
  }
  vapply(features, function(item) {
    href <- item$assets[[selection$asset]]$href
    if (!has_text(href)) {
      biab_error_stop(paste0("STAC item ", item$id, " has no asset named ", selection$asset, "."))
    }
    href
  }, character(1))
}

raster_paths <- character()
for (index in seq_along(input$stac)) {
  selection <- input$stac[[index]]
  for (field in c("catalog", "collection", "asset")) {
    if (!has_text(selection[[field]])) {
      biab_error_stop(paste0("STAC selection ", index, " is missing ", field, "."))
    }
  }
  print("url output")
  print(RCurl::url.exists(selection$catalog))
  coll_it <- if (isTRUE(selection$items_are_tiles)) selection$collection else
    paste(selection$collection, selection$item, sep = "|")
  print(coll_it)
  flush(stdout())
  tryCatch({
    hrefs <- selection_hrefs(selection)
    if (isTRUE(selection$items_are_tiles)) {
      print("Asset names:")
      print(rep(selection$asset, length(hrefs)))
      print("Pulling all items")
      if (has_text(selection$date)) print(selection$date)
      print(selection$asset)
      flush(stdout())
    }
    source <- read_asset(hrefs[1])
    print(target_crs)
    grid_resolution <- resolution
    if (is.null(grid_resolution)) {
      if (!terra::same.crs(source, target_crs)) {
        biab_error_stop("Please provide a spatial resolution when changing the asset's CRS.")
      }
      grid_resolution <- terra::res(source)
    }
    print(grid_resolution)
    flush(stdout())
    grid <- terra::rast(target_extent, resolution = grid_resolution, crs = target_crs)
    method <- input$resampling
    if (!has_text(method)) {
      method <- "bilinear"
      if (!isTRUE(selection$categorical)) {
        print("No resampling method selected, defaulting to bilinear.")
      }
    }
    categorical <- isTRUE(selection$categorical)
    if (categorical) {
      method <- input$categorical_resampling
      if (!has_text(method)) {
        method <- "near"
        print("No resampling method selected, defaulting to near.")
      }
      if (!method %in% c("near", "mode")) {
        biab_error_stop("Categorical resampling must be near or mode.")
      }
    }
    aggregation <- if (categorical) input$categorical_aggregation else input$continuous_aggregation
    if (!has_text(aggregation)) {
      aggregation <- "first"
      print("No aggregation method selected, defaulting to first.")
    }
    allowed <- if (categorical) c("first", "last", "modal") else
      c("first", "last", "mean", "median", "min", "max", "sum")
    if (!aggregation %in% allowed) {
      biab_error_stop(paste0("Unsupported aggregation method: ", aggregation))
    }

    # Crop in the source CRS before reprojecting to avoid reading entire tile sets.
    area <- terra::as.polygons(target_extent, crs = target_crs)
    layers <- list()
    for (href in hrefs) {
      tile <- read_asset(href)
      crop_extent <- terra::ext(terra::project(area, terra::crs(tile)))
      overlap <- terra::intersect(terra::ext(tile), crop_extent)
      if (is.null(overlap)) next
      tile <- terra::crop(tile, overlap, snap = "out")
      # Project only the tile's portion of the common grid.
      tile_extent <- terra::ext(terra::project(terra::as.polygons(terra::ext(tile),
        crs = terra::crs(tile)), target_crs))
      tile_grid <- terra::crop(grid, tile_extent, snap = "out")
      layers[[length(layers) + 1L]] <- terra::project(tile, tile_grid, method = method)
    }
    if (length(layers) == 0L) {
      biab_error_stop("The selected STAC assets do not overlap the bounding box.")
    }
    # Aggregate overlapping tiles using the method for this layer's data type.
    result <- if (length(layers) == 1L) layers[[1]] else if (aggregation == "first")
      do.call(terra::merge, c(layers, list(first = TRUE))) else
      terra::mosaic(terra::sprc(layers), fun = aggregation)
    result <- terra::extend(result, grid)
    if (!is.null(study_area)) result <- terra::mask(result, study_area)

    scope <- if (isTRUE(selection$items_are_tiles)) selection$date else selection$item
    label <- paste(c(selection$collection, scope, selection$asset), collapse = "_")
    label <- gsub("[^A-Za-z0-9_-]", "_", label)
    path <- file.path(outputFolder, paste0(index, "_", label, ".tif"))
    print(path)
    flush(stdout())
    terra::writeRaster(result, path, overwrite = TRUE, gdal = "COMPRESS=DEFLATE")
    raster_paths <- c(raster_paths, path)
  }, error = function(error) {
    biab_error_stop(paste0("Could not load STAC selection ", index, ": ", conditionMessage(error)))
  })
}

biab_output("rasters", as.list(raster_paths))
