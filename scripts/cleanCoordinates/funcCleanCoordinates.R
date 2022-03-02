#' @param x, a dataframe of observation containing at least: decimal coordinates into two columns and one unique identifier column 
#' @param predictors, raster stack of predictors
#' @param unique_id, column name containing a unique row identifier
#' @param species_col, column name containing the species name
#' @param lat, column name containing projected latitude, MUST BE same projection as the predictors raster
#' @param lon, column name containing projected longitude, MUST BE same projection as the predictors raster
#' @param tests a vector of character strings, indicating which tests to run. 
#' See details for all tests available. Default = c("capitals", "centroids", 
#' "equal", "gbif", "institutions", "duplicates", "urban",
#' "seas", "zeros"). See parameters of each test at https://github.com/ropensci/CoordinateCleaner/blob/master/R/clean_coordinates.R
#' @param value a character string defining the output value (clean or flagged). See return.
#' @param report logical or character.  If TRUE a report file is written to the
#' directory dir, summarizing the cleaning results. Default = FALSE.
#' @param species_name, string. If export, a folder with the species name will be created in the "dir" directory
#' @param dir character, directory to write the cleaning results.
#' @return If value == 'clean', a dataframe with problematic observations removed: nrows<= nrows(x)
#' if value == 'flagged', observations dataframe x with a column 'flagged'
#'TRUE = clean coordinate, FALSE = potentially problematic (= at least one test failed).
#' @import CoordinateCleaner
#' @import dplyr


cleanCoordinates <- function(x,
                              predictors,
                                 unique_id = "id",
                                 lon = "lon", 
                                 lat = "lat", 
                              species_col = "scientific_name",
                                 tests = c( 
                                            "equal",
                                            "zeros", 
                                            "duplicates", 
                                            "same_pixel",
                                            "capitals", 
                                            "centroids",
                                            "seas", 
                                            "urban",
                                            "gbif", 
                                            "institutions",
                                            "env"
                                            
                                 ),
                                 capitals_rad = 10000,
                                 centroids_rad = 1000, 
                                 centroids_detail = "both", 
                                 inst_rad = 100, 
                                 range_rad = 0,
                                 zeros_rad = 0.5,
                                threshold_env = 0.5,
                             predictors_env = NULL,
                                 capitals_ref = NULL, 
                                 centroids_ref = NULL, 
                                 inst_ref = NULL, 
                                 range_ref = NULL,
                                 seas_ref = NULL, 
                                 seas_scale = 10,
                                 additions = NULL,
                                 urban_ref = NULL, 
                                 verbose = TRUE, 
                                 species_name = NULL) {
  # check function arguments
  match.arg(value, choices = c("flagged", "clean"))
  match.arg(centroids_detail, choices = c("both", "country", "provinces"))
  
  
  # check column names
  nams <- c(unique_id, lon, lat, species_col)
  if (!all(nams %in% names(x))) {
    stop(sprintf("%s column not found\n", nams[which(!nams %in% names(x))]))
  }
  
  # If proj is not lon/lat, transform coordinates to lon/lat to ensure further tests
  
  x <- createDecimalCoordinates(x, lon = lon, lat = lat, crs_init = crs(predictors)@projargs)
  
  # Run tests Validity, check if coordinates fit to lat/long system, this has
  # to be run all the time, as otherwise the other tests don't work
  val <- cc_val(x, lon = "decimalLon", lat =  "decimalLat", 
                verbose = verbose, value = "flagged")
  
  x1 <- x[!val,]

  # For later test, only keep valid coordinates obs
  x <- x[val,]
  

  
  ## Remove NA in predictors
  message("cleaning occurrences with no environmental data")
  if (!class(predictors) %in% c("RasterBrick", "RasterStack")) {
    predictors <- raster::stack(predictors) # on utilise fonction subset du package raster sinon pb de comptaibitli
  }

  presvals <- terra::extract(rast(predictors), dplyr::select(x, all_of(c(lon, lat ))) %>%
                                data.frame())
  
  comp <-  complete.cases(presvals)
  x <-  x[comp, ]
  
  if (nrow(x) == 0) stop("All occurrence points are outside the predictor variable rasters")
  message(sprintf("Removed %s records with no environmental data.",nrow(presvals) - nrow(x)))

  

  
  # Initiate output 

  allTests <- c( "val", "equ", "zer", "dup", "pixel", "cap", "cen", "sea", "urb",
                      "gbf", "inst", "env")
  out <- data.frame(matrix(NA, nrow = nrow(x), ncol = length(allTests)))
  names(out) <- allTests

  
  ## Equal coordinates
  if ("equal" %in% tests) {
    out$equ <- CoordinateCleaner::cc_equ(x,
                      lon = "decimalLon", lat = "decimalLat", verbose = verbose, value = "flagged",
                      test = "absolute"
    )
  }
  
  ## Zero coordinates
  if ("zeros" %in% tests) {
    out$zer <- CoordinateCleaner::cc_zero(x,
                       lon = "decimalLon", lat = "decimalLat", buffer = zeros_rad, verbose = verbose,
                       value = "flagged"
    )
  }
  
  ## Duplicates
  if ("duplicates" %in% tests) {
    out$dup <-CoordinateCleaner::cc_dupl(x, lon = "decimalLon" , lat = "decimalLat", species = species_col, additions = additions,
                      value = "flagged")
    
  }
  
  ## Same pixel
  if ("same_pixel" %in% tests) {
    if (verbose) {
      message("Testing observations in the same pixel")
    }
    mask <- predictors[[1]]
    cell <- raster::cellFromXY(mask,  dplyr::select(x, lon, lat ) %>% data.frame())
    dup <- duplicated(cell)
    out$pixel <- !dup
    if (verbose) {
      message(sprintf("Flagged %s records.", sum(dup)))
      
    }
    
  }
  
  ## Capitals
  if ("capitals" %in% tests) {
    out$cap <- CoordinateCleaner::cc_cap(x,
                      lon = "decimalLon", lat = "decimalLat", buffer = capitals_rad, ref = capitals_ref,
                      value = "flagged", verbose = verbose
    )
  }
  
  ## Centroids
  if ("centroids" %in% tests) {
    out$cen <- CoordinateCleaner::cc_cen(x,
                                         species = species_col,
                      lon = "decimalLon", lat = "decimalLat", buffer = centroids_rad, test = centroids_detail,
                      ref = countryref, value = "flagged", verbose = verbose
    )
  }
  
  ## Seas
  if ("seas" %in% tests) {
    out$sea <- CoordinateCleaner::cc_sea(x,
                      lon = "decimalLon", lat = "decimalLat", ref = seas_ref, 
                      scale = seas_scale,
                      verbose = verbose,
                      value = "flagged"
    )
  }
  
  ## Urban Coordinates
  if ("urban" %in% tests) {
    out$urb <- cc_urb(x,
                      
                      lon = "decimalLon", lat = "decimalLat", ref = urban_ref, verbose = verbose,
                      value = "flagged"
    )
  }
  
  ## GBIF headquarters
  if ("gbif" %in% tests) {
    out$gbf <- CoordinateCleaner::cc_gbif(x, lon = "decimalLon", lat = "decimalLat", 
                       verbose = verbose, value = "flagged")
  }
  
  ## Biodiversity institution
  if ("institutions" %in% tests) {
    out$inst <- CoordinateCleaner::cc_inst(x,
                        lon = "decimalLon", lat = "decimalLat", ref = inst_ref, buffer = inst_rad,
                        verbose = verbose, value = "flagged"
    )
  }
  
  ## Environmental outliers
  if ("env" %in% tests){
    out$env <- cc_env_out(x, 
                          lon = lon, 
                          lat = lat, 
                          predictors = predictors,
                          cols = predictors_env,
                          threshold = threshold_env,
                          value = "flagged",
                          verbose = TRUE
    )
  }
  
    
  # prepare output data
  
 
  
  if (nrow(x1) > 0) {
    x <- bind_rows(x1, x)
    
    out_val <- data.frame(matrix(NA, nrow = nrow(x1), ncol = length(allTests))) 
    names(out_val) <- allTests
    out_val <- out_val %>%
      mutate(val = F)
    out <- out %>%
      mutate(val = T)
    out <- rbind(out_val,
                     out)
  }
  out <- Filter(function(x) !all(is.na(x)), out)
  suma <- as.vector(Reduce("&", out))
  
  if (verbose) {
    if (!is.null(suma)) {
      message(sprintf("Flagged %s of %s records, EQ = %s.", sum(!suma,
                                                                na.rm = TRUE
      ), length(suma), round(
        sum(!suma, na.rm = TRUE) / length(suma), 2
      )))
    } else {
      message("flagged 0 records, EQ = 0")
    }
  }
  
  ret <- data.frame(dplyr::select(x, all_of(c(unique_id, species_col, lon, lat))), out, summary = suma)
  names(ret) <- c(c("id", "scientific_name", lon, lat),
                  paste(".", names(out), sep = ""),
                  ".summary")
  
  
  repo <- bind_cols(out %>%
                      dplyr::summarise(across(everything(), ~ sum(!.x, na.rm = TRUE))),
                    nb_init = length(suma),
                    nb_flagged = sum(!suma,
                                     na.rm = TRUE
                    ),
                    EQ = round(
                      sum(!suma, na.rm = TRUE) / length(suma), 2
                    ))
  
  
  
flagged.obs <- ret %>% data.frame()
clean.obs <- ret[suma, ] %>% dplyr::select(id, scientific_name, lon, lat) %>% data.frame()


  return(list("flagged" = flagged.obs, "clean" = clean.obs, "report" = repo))
}

# Impoirted and modified from CoordinateCleaner
cc_urb <- function (x, lon = "decimallongitude", lat = "decimallatitude", 
                    ref = NULL, value = "clean", verbose = TRUE) {
  match.arg(value, choices = c("clean", "flagged"))
  if (verbose) {
    message("Testing urban areas")
  }
  if (is.null(ref)) {
    message("Downloading urban areas via rnaturalearth")
    ref <- try(suppressWarnings(rnaturalearth::ne_download(scale = "medium", 
                                                           type = "urban_areas")), silent = TRUE)
    if (class(ref) == "try-error") {
      warning(sprintf("Gazetteer for urban areas not found at\n%s", 
                      rnaturalearth::ne_file_name(scale = "medium", 
                                                  type = "urban_areas", full_url = TRUE)))
      warning("Skipping urban test")
      switch(value, clean = return(x), flagged = return(rep(NA, 
                                                            nrow(x))))
    }
    sp::proj4string(ref) <- ""
  }
  else {
    if (!any(is(ref) == "Spatial")) {
      ref <- as(ref, "Spatial")
    }
    ref <- reproj(ref)
  }
  wgs84 <- "+proj=longlat +datum=WGS84 +no_defs"
  dat <- sp::SpatialPoints(x[, c(lon, lat)], proj4string = CRS(wgs84))
  limits <- raster::extent(dat) + 1
  ref <- raster::crop(ref, limits)
  
  if (is.null(ref)) {
    out <- rep(TRUE, nrow(x))
  }
  else {
    proj4string(ref) <- wgs84
    out <- is.na(sp::over(x = dat, y = ref)[, 1])
  }
  if (verbose) {
    if (value == "clean") {
      message(sprintf("Removed %s records.", sum(!out)))
    }
    else {
      message(sprintf("Flagged %s records.", sum(!out)))
    }
  }
  switch(value, clean = return(x[out, ]), flagged = return(out))
}


createDecimalCoordinates <- function(obs, lon, lat, crs_init) {
  wgs84 <- "+proj=longlat +datum=WGS84 +no_defs"
  coords <- dplyr::select(obs, all_of(c(lon, lat)))
  sp::coordinates(coords) <- c(lon, lat)
  proj4string(coords) <- CRS(crs_init)
  coordsDecimal <- data.frame(spTransform(coords, CRS(wgs84)))%>% 
    setNames(c("decimalLon", "decimalLat"))
  #Suppress warnings: dplyr one_of creates a warning if column names do not exist
  suppressWarnings(obs <- obs %>%
                     dplyr::select(-one_of(c("decimalLon", "decimalLat"))) %>% bind_cols(coordsDecimal))
  return(obs)
}