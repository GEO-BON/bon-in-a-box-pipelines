# Load the assets produced by the STAC chooser (stac_asset[]).
library(terra)

input <- biab_inputs()

has_text <- function(value) {
  is.character(value) && length(value) == 1L && !is.na(value) && nzchar(value)
}

# Apply defaults only when a processing option is omitted.
read_option <- function(name, default, allowed) {
  value <- input[[name]]
  if (is.null(value)) return(default)
  if (!has_text(value) || !value %in% allowed) {
    biab_error_stop(paste0(name, " must be one of ", paste(allowed, collapse = ", "), "."))
  }
  value
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

continuous_resampling <- read_option("resampling", "bilinear",
  c("near", "bilinear", "cubic", "cubicspline", "lanczos", "average", "mode"))
categorical_resampling <- read_option("categorical_resampling", "near", c("near", "mode"))
continuous_aggregation <- read_option("continuous_aggregation", "first",
  c("first", "last", "mean", "median", "min", "max", "sum"))
categorical_aggregation <- read_option("categorical_aggregation", "first", c("first", "last", "modal"))

# Check the input structure before reading the bounding box and CRS fields.
bbox_crs <- input[["bbox_crs"]]
if (!is.list(bbox_crs)) biab_error_stop("Please select a bounding box and CRS.")
bbox <- unlist(bbox_crs[["bbox"]], use.names = FALSE)
crs_info <- bbox_crs[["CRS"]]
if (!is.list(crs_info)) biab_error_stop("Please select a bounding box and CRS.")
authority <- crs_info[["authority"]]
code <- crs_info[["code"]]
valid_code <- has_text(code) || (is.numeric(code) && length(code) == 1L && is.finite(code))
if (length(bbox) != 4L || !is.numeric(bbox) || any(!is.finite(bbox)) ||
    !has_text(authority) || !valid_code) {
  biab_error_stop("Please select a bounding box and CRS.")
}
if (bbox[1] >= bbox[3] || bbox[2] >= bbox[4]) {
  biab_error_stop("The bounding box must have left < right and bottom < top.")
}
target_crs <- paste0(authority, ":", code)
target_extent <- terra::ext(bbox[c(1, 3, 2, 4)])
resolution <- input$spatial_res
if (!is.null(resolution) &&
    (!is.numeric(resolution) || length(resolution) != 1L ||
     !is.finite(resolution) || resolution <= 0)) {
  biab_error_stop("Spatial resolution must be a positive number in the target CRS units.")
}

study_area <- NULL
if (has_text(input$study_area)) {
  # Report which step failed while preparing the study area.
  study_area <- tryCatch(terra::vect(input$study_area), error = function(error) {
    biab_error_stop(paste0("Could not open the study-area file: ", conditionMessage(error)))
  })
  study_area <- tryCatch(terra::project(study_area, target_crs), error = function(error) {
    biab_error_stop(paste0("Could not reproject the study area to ", target_crs, ": ", conditionMessage(error)))
  })
}

# HTTP raster reads use GDAL's range requests rather than downloading whole files.
Sys.setenv(GDAL_DISABLE_READDIR_ON_OPEN = "EMPTY_DIR", VSI_CACHE = "TRUE")

read_asset <- function(href) {
  if (!has_text(href)) biab_error_stop("The selected STAC asset has no usable href.")
  path <- if (grepl("^https?://", href)) paste0("/vsicurl/", href) else href
  terra::rast(path)
}

# Planetary Computer assets need a SAS token appended to their hrefs.
is_planetary_computer <- function(catalog) {
  grepl("planetarycomputer.microsoft.com", catalog, fixed = TRUE)
}

is_absolute_asset_href <- function(href) {
  grepl("^[A-Za-z][A-Za-z0-9+.-]*:|^/vsi", href)
}

# Resolve relative asset links against the item before signing them.
resolve_asset_href <- function(href, item, item_url = NULL) {
  if (is_absolute_asset_href(href)) return(href)
  for (link in item$links) {
    if (identical(link$rel, "self") && has_text(link$href) &&
        grepl("^[A-Za-z][A-Za-z0-9+.-]*:", link$href)) {
      item_url <- link$href
      break
    }
  }
  if (!has_text(item_url)) {
    biab_error_stop(paste0("STAC item ", item$id, " has a relative asset link but no item URL."))
  }
  xml2::url_absolute(href, item_url)
}

sign_asset_href <- function(href, catalog) {
  if (!is_planetary_computer(catalog)) return(href)
  signed <- rstac::sign_planetary_computer()(list(assets = list(list(href = href))))
  signed$assets[[1]]$href
}

is_unbl <- function(catalog) {
  grepl("stac.api.unbiodiversitylab.org", catalog, fixed = TRUE)
}

# The UN Biodiversity Lab STAC API requires an API key header.
catalog_headers <- function(catalog) {
  if (!is_unbl(catalog)) return(NULL)
  httr::add_headers(`X-API-Key` = Sys.getenv("UNBL_API_KEY"))
}

selection_hrefs <- function(selection) {
  headers <- catalog_headers(selection$catalog)
  if (!isTRUE(selection$items_are_tiles)) {
    href <- selection$href
    if (has_text(href) && is_absolute_asset_href(href)) {
      return(sign_asset_href(href, selection$catalog))
    }
    if (!has_text(selection$item)) biab_error_stop("The selection is missing its STAC item.")
    item <- rstac::stac(selection$catalog) |>
      rstac::collections(selection$collection) |>
      rstac::items(selection$item) |>
      rstac::get_request(headers)
    if (!has_text(href)) href <- item$assets[[selection$asset]]$href
    if (!has_text(href)) biab_error_stop("The selected STAC asset has no usable href.")
    item_url <- paste0(sub("/+$", "", selection$catalog), "/collections/",
      utils::URLencode(selection$collection, reserved = TRUE), "/items/",
      utils::URLencode(selection$item, reserved = TRUE))
    href <- resolve_asset_href(href, item, item_url)
    return(sign_asset_href(href, selection$catalog))
  }

  # Collection endpoints work with both static catalogs and STAC APIs.
  items <- rstac::stac(selection$catalog) |>
    rstac::collections(selection$collection) |>
    rstac::items() |>
    rstac::get_request(headers) |>
    rstac::items_fetch(headers)
  features <- items$features
  item_day <- function(item) {
    timestamp <- item$properties$datetime
    if (!has_text(timestamp)) timestamp <- item$properties$start_datetime
    if (!has_text(timestamp)) return(NA_character_)

    # Match the chooser's UTC day and normalize the offset for strptime's %z.
    pattern <- "^[0-9]{4}-[0-9]{2}-[0-9]{2}[Tt][0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]+)?([Zz]|[+-][0-9]{2}:[0-9]{2})$"
    parsed <- NA
    if (grepl(pattern, timestamp)) {
      timestamp <- sub("[Zz]$", "+0000", toupper(timestamp))
      timestamp <- sub("([+-][0-9]{2}):([0-9]{2})$", "\\1\\2", timestamp)
      parsed <- strptime(timestamp, "%Y-%m-%dT%H:%M:%OS%z", tz = "UTC")
    }
    if (is.na(parsed)) {
      biab_error_stop(paste0("STAC item ", item$id, " has an invalid timestamp."))
    }
    format(parsed, "%Y-%m-%d", tz = "UTC")
  }
  days <- vapply(features, item_day, character(1))
  # Require a date when dated and undated tiles would otherwise be mixed.
  if (has_text(selection$date)) {
    features <- features[!is.na(days) & days == selection$date]
  } else if (anyNA(days) && any(!is.na(days))) {
    biab_error_stop(paste(
      "This tile collection contains both dated and undated items.",
      "Please choose a date in the STAC chooser."
    ))
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
    href <- resolve_asset_href(href, item)
    sign_asset_href(href, selection$catalog)
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
  # Reject malformed flags before they can change how the selection is processed.
  for (field in c("categorical", "items_are_tiles")) {
    flag <- selection[[field]]
    if (!is.null(flag) && (!is.logical(flag) || length(flag) != 1L || is.na(flag))) {
      biab_error_stop(paste0("STAC selection ", index, " field ", field, " must be true or false."))
    }
    selection[[field]] <- isTRUE(flag)
  }
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
    method <- if (selection$categorical) categorical_resampling else continuous_resampling
    aggregation <- if (selection$categorical) categorical_aggregation else continuous_aggregation

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
    # Check the masked raster for valid pixels before writing it.
    valid_cells <- terra::global(result, "notNA")
    if (!any(valid_cells$notNA > 0)) {
      biab_error_stop("The output raster has no valid pixels in the requested area.")
    }

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
