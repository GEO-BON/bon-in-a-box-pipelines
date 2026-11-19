## Load required packages
library("terra")
library("rjson")
library("raster")
library("CoordinateCleaner")
library("dplyr")

## Load functions
source(paste(Sys.getenv("SCRIPT_LOCATION"), "filtering/cleanCoordinatesFunc.R", sep = "/"))
source(paste(Sys.getenv("SCRIPT_LOCATION"), "SDM/sdmUtils.R", sep = "/"))

input <- biab_inputs()
print("Inputs: ")
print(input)

presence <- read.table(file = input$presence, sep = "\t", header = TRUE)

# Import of predictors
predictors <- terra::rast(unlist(input$predictors))
proj <- terra::crs(predictors)

custom_path <- input$custom_occurrences
if (!is.null(custom_path) && length(custom_path) == 1 && !is.na(custom_path) && nzchar(custom_path)) {
  header <- readLines(custom_path, n = 1, warn = FALSE)
  if (length(header) == 0) {
    stop("The uploaded occurrence file is empty.")
  }
  separator <- if (grepl("\t", header, fixed = TRUE)) "\t" else ","
  custom <- read.table(
    file = custom_path,
    sep = separator,
    header = TRUE,
    check.names = FALSE,
    stringsAsFactors = FALSE,
    comment.char = ""
  )

  required_columns <- c("scientific_name", "decimal_longitude", "decimal_latitude")
  missing_columns <- setdiff(required_columns, names(custom))
  if (length(missing_columns) > 0) {
    stop(sprintf(
      "The uploaded occurrence file is missing required columns: %s.",
      paste(missing_columns, collapse = ", ")
    ))
  }
  if (nrow(custom) == 0) {
    stop("The uploaded occurrence file has no records.")
  }

  custom$scientific_name <- trimws(as.character(custom$scientific_name))
  if (anyNA(custom$scientific_name) || any(!nzchar(custom$scientific_name))) {
    stop("Every uploaded occurrence must have a scientific_name.")
  }

  for (coordinate in c("decimal_longitude", "decimal_latitude")) {
    values <- suppressWarnings(as.numeric(as.character(custom[[coordinate]])))
    if (any(!is.finite(values))) {
      stop(sprintf("Uploaded %s values must all be finite numbers.", coordinate))
    }
    custom[[coordinate]] <- values
  }

  if ("id" %in% names(custom)) {
    upload_ids <- trimws(as.character(custom$id))
    missing_ids <- is.na(upload_ids) | !nzchar(upload_ids)
    upload_ids[missing_ids] <- paste0("row_", which(missing_ids))
    custom$id <- make.unique(paste0("user_", upload_ids), sep = "_")
  } else {
    custom$id <- paste0("user_row_", seq_len(nrow(custom)))
  }

  custom_crs <- input$custom_occurrences_crs
  source_crs <- "EPSG:4326"
  if (is.character(custom_crs) && length(custom_crs) == 1 &&
      (is.na(custom_crs) || !nzchar(custom_crs))) {
    custom_crs <- NULL
  }
  if (!is.null(custom_crs)) {
    if (is.character(custom_crs) && length(custom_crs) == 1 && nzchar(custom_crs)) {
      source_crs <- custom_crs
    } else if (!is.null(custom_crs$CRS$authority) && !is.null(custom_crs$CRS$code)) {
      source_crs <- paste0(custom_crs$CRS$authority, ":", custom_crs$CRS$code)
    } else {
      stop("The uploaded occurrence CRS must be a valid CRS selection.")
    }
  }
  source_crs <- sf::st_crs(source_crs)
  if (is.na(source_crs)) {
    stop("The uploaded occurrence CRS is not recognized.")
  }

  custom_sf <- sf::st_as_sf(
    custom,
    coords = c("decimal_longitude", "decimal_latitude"),
    crs = source_crs,
    remove = FALSE
  ) |>
    sf::st_transform(crs = "EPSG:4326")
  custom_coordinates <- sf::st_coordinates(custom_sf)
  if (any(!is.finite(custom_coordinates))) {
    stop("The uploaded occurrence coordinates could not be transformed to EPSG:4326.")
  }
  custom$decimal_longitude <- custom_coordinates[, 1]
  custom$decimal_latitude <- custom_coordinates[, 2]
  presence$id <- as.character(presence$id)
  presence <- dplyr::bind_rows(
    presence,
    dplyr::select(
      custom,
      id,
      scientific_name,
      decimal_longitude,
      decimal_latitude
    )
  )
}

biab_output("n_presence", nrow(presence))

# Projecting observations into predictors projection
presence <- create_projection(presence,
  lon = "decimal_longitude", lat = "decimal_latitude",
  proj_from = "+proj=longlat +datum=WGS84", proj_to = proj, new_lon = "lon", new_lat = "lat"
)

# Cleaning the data
clean_presence <- clean_coordinates(
  x = presence,
  predictors = predictors,
  species_name = species,
  unique_id = "id",
  lon = "lon",
  lat = "lat",
  species_col = "scientific_name",
  tests = input$tests,
  threshold_env = input$threshold_env,
  report = F,
  value = "clean"
)
clean_presence <- clean_presence |> # summary = TRUE means the observations was identified as an outlier at least once during the cleaning procedure
  dplyr::select(id, scientific_name, lon, lat)

if (nrow(clean_presence) == 0) {
  biab_error_stop("No occurences left after cleaning for the species of interest in this country/region.")
}

clean_presence.output <- file.path(outputFolder, "clean_presence.tsv")

write.table(clean_presence, clean_presence.output,
  append = F, row.names = F, col.names = T, sep = "\t"
)

biab_output("n_clean", nrow(clean_presence))
biab_output("clean_presence", clean_presence.output)
