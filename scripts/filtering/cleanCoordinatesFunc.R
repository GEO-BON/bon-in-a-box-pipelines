#' @title Clean
#'
#' @name clean_coordinates
#' @param x, a dataframe of observation containing at least:
#' decimal coordinates into two columns and one unique identifier column
#' @param predictors, raster stack of predictors
#' @param unique_id, column name containing a unique row identifier
#' @param species_col, column name containing the species name
#' @param lat, column name containing projected latitude, MUST BE 
#' same projection as the predictors raster
#' @param lon, column name containing projected longitude, MUST BE 
#' same projection as the predictors raster
#' @param tests a vector of character strings, indicating which tests to run.
#' See details for all tests available. Default = c("capitals", "centroids",
#' "equal", "gbif", "institutions", "duplicates", "urban",
#' "seas", "zeros", "env"). See parameters of each test at https://github.com/ropensci/CoordinateCleaner/blob/master/R/clean_coordinates.R
#' @param value a character string defining the output value (clean or flagged). See return.
#' @param report logical or character.  If TRUE a report file is written to the
#' directory dir, summarizing the cleaning results. Default = FALSE.
#' @param species_name, string. If export, a folder with the species name will be created in the "dir" directory
#' @param dir character, directory to write the cleaning results.
#' @return If value == 'clean', a dataframe with problematic observations removed: nrows<= nrows(x)
#' if value == 'flagged', observations dataframe x with a column 'flagged'
#'TRUE = clean coordinate, FALSE = potentially problematic (= at least one test failed).
#' @import CoordinateCleaner dplyr 
#' @export

clean_coordinates <- function(x,
                              predictors = NULL,
                              unique_id = "id",
                              lon = "lon", 
                              lat = "lat", 
                              species_col = "scientificName",
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
                              country_ref = NULL,
                              capitals_ref = NULL, 
                              centroids_ref = NULL, 
                              inst_ref = NULL, 
                              range_ref = NULL,
                              seas_ref = NULL, 
                              seas_scale = 10,
                              additions = NULL,
                              urban_ref = NULL, 
                              verbose = TRUE, 
                              species_name = NULL,
                              report = T,
                              dir = getwd(),
                              value = "all") {
  # check function arguments
  match.arg(centroids_detail, choices = c("both", "country", "provinces"))
  
  
  # check column names
  nams <- c(unique_id, lon, lat, species_col)
  if (!all(nams %in% names(x))) {
    stop(sprintf("%s column not found\n", nams[which(!nams %in% names(x))]))
  }
  
  # If proj is not lon/lat, transform coordinates to lon/lat to ensure further tests
  
  proj <- terra::crs(predictors) 

  x <- create_projection(x, lon, lat,
                         proj_from = proj,
                         proj_to = "EPSG:4326", 
                         new_lon = "decimalLongitude",
                         new_lat = "decimalLatitude")
  
  # Run tests Validity, check if coordinates fit to lat/long system, this has
  # to be run all the time, as otherwise the other tests don't work
  val <- CoordinateCleaner::cc_val(x, lon = "decimalLongitude", lat =  "decimalLatitude", 
                                   verbose = verbose, value = "flagged")
  
  x1 <- x[!val,]
  
  # For later test, only keep valid coordinates obs
  x <- x[val,]
  
  
  
  ## Remove NA in predictors
  message("cleaning occurrences with no environmental data")
  
    
    presvals <- terra::extract(predictors, dplyr::select(x, all_of(c(lon, lat ))) %>%
                                 data.frame()) 
    comp <-  complete.cases(presvals)
    x <-  x[comp, ]
    presvals <-  presvals[comp, ]
  
  covars <- names(predictors)
  presvals <- dplyr::select(presvals, 
                            dplyr::all_of(c(covars))) %>% data.frame()
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
                                         lon = "decimalLongitude", lat = "decimalLatitude", verbose = verbose, value = "flagged",
                                         test = "absolute"
    )
  }
  
  ## Zero coordinates
  if ("zeros" %in% tests) {
    out$zer <- CoordinateCleaner::cc_zero(x,
                                          lon = "decimalLongitude", lat = "decimalLatitude", buffer = zeros_rad, verbose = verbose,
                                          value = "flagged"
    )
  }
  
  ## Duplicates
  if ("duplicates" %in% tests) {
    out$dup <-CoordinateCleaner::cc_dupl(x, lon = "decimalLongitude" , lat = "decimalLatitude", species = species_col, additions = additions,
                                         value = "flagged")
    
  }
  
  ## Same pixel
  if ("same_pixel" %in% tests) {
    if (verbose) {
      message("Testing observations in the same pixel")
    }
    
       
    mask <- predictors[[1]]
   
    cell <- terra::cellFromXY(mask, 
                              xy <- as.matrix(dplyr::select(x, dplyr::all_of(c(lon, lat)))))
    dup <- duplicated(cell)
    out$pixel <- !dup
    if (verbose) {
      message(sprintf("Flagged %s records.", sum(dup)))
      
      
    }
  }
  ## Capitals
  if ("capitals" %in% tests) {
    out$cap <- CoordinateCleaner::cc_cap(x,
                                         lon = "decimalLongitude", lat = "decimalLatitude", buffer = capitals_rad, ref = capitals_ref,
                                         value = "flagged", verbose = verbose
    )
  }
  
  ## Centroids
  if ("centroids" %in% tests) {
    out$cen <- CoordinateCleaner::cc_cen(x,
                                         species = species_col,
                                         lon = "decimalLongitude", lat = "decimalLatitude", buffer = centroids_rad, test = centroids_detail,
                                         ref = country_ref, value = "flagged", verbose = verbose
    )
  }
  
  ## Seas
  if ("seas" %in% tests) {
    out$sea <- CoordinateCleaner::cc_sea(x,
                                         lon = "decimalLongitude", lat = "decimalLatitude", ref = seas_ref, 
                                         scale = seas_scale,
                                         verbose = verbose,
                                         value = "flagged"
    )
  }
  
  ## Urban Coordinates
  if ("urban" %in% tests) {
    out$urb <- cc_urb(x,
                      
                      lon = "decimalLongitude", lat = "decimalLatitude", ref = urban_ref, verbose = verbose,
                      value = "flagged"
    )
  }
  
  ## GBIF headquarters
  if ("gbif" %in% tests) {
    out$gbf <- CoordinateCleaner::cc_gbif(x, lon = "decimalLongitude", lat = "decimalLatitude", 
                                          verbose = verbose, value = "flagged")
  }
  
  ## Biodiversity institution
  if ("institutions" %in% tests) {
    out$inst <- CoordinateCleaner::cc_inst(x,
                                           lon = "decimalLongitude", lat = "decimalLatitude", ref = inst_ref, buffer = inst_rad,
                                           verbose = verbose, value = "flagged"
    )
  }
  
  ## Environmental outliers
  if ("env" %in% tests){
    out$env <- cc_env_out(presvals,
                          cols = predictors_env,
                          threshold = threshold_env,
                          value = "flagged",
                          verbose = TRUE
    )
  }
  
  
  # prepare output data
  
  
  
  if (nrow(x1) > 0) {
    x <- dplyr::bind_rows(x1, x)
    
    out_val <- data.frame(matrix(NA, nrow = nrow(x1), ncol = length(allTests))) 
    names(out_val) <- allTests
    out_val <- out_val %>%
      dplyr::mutate(val = F)
    out <- out %>%
      dplyr::mutate(val = T)
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
  names(ret) <- c(c("id", "scientific_name", "lon", "lat"),
                  paste(".", names(out), sep = ""),
                  ".summary")
  
  
  repo <- dplyr::bind_cols(out %>%
                             dplyr::summarise(across(everything(), ~ sum(!.x, na.rm = TRUE))),
                           nb_init = length(suma),
                           nb_flagged = sum(!suma,
                                            na.rm = TRUE
                           ),
                           EQ = round(
                             sum(!suma, na.rm = TRUE) / length(suma), 2
                           ))
  
  
  
  flagged.obs <- ret %>% data.frame() 
  clean.obs <- ret[suma, ] %>% dplyr::select(dplyr::all_of(c("id", "scientific_name", "lon", "lat"))) %>% data.frame()
  
  
  if (report) {
    outputDir <- paste(dir, species_name, sep = "/")
    dir.create(file.path(outputDir), showWarnings = FALSE) #dir.create() does not crash if the directory already exists}
    
    report <- paste0(outputDir, "/clean_coordinates_report.csv")
    flag_occ <- paste0(outputDir, "/flagg_occ.csv")
  }
  if (is.character(report)) {
    write.table(repo, report, sep = ";", row.names = FALSE, quote = FALSE)
    write.table(ret, flag_occ, sep = ";", row.names = FALSE, quote = FALSE)  
    message(sprintf("Cleaning report saved in %s.", report))
    message(sprintf("Flagged occurrences saved in %s.", flag_occ))
  }
  
  switch(value, clean = return(clean.obs), flagged = return(flagged.obs),
         all = return(list("flagged" = flagged.obs, "clean" = clean.obs, "report" = repo)))
  
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
                                                           type = "urban_areas")),
               silent = TRUE)
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
  dat <- sp::SpatialPoints(x[, c(lon, lat)], proj4string = sp::CRS(wgs84))
  limits <- raster::extent(dat) + 1
  ref <- raster::crop(ref, limits)
  
  if (is.null(ref)) {
    out <- rep(TRUE, nrow(x))
  }
  else {
    sp::proj4string(ref) <- wgs84
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
                                                           type = "urban_areas")),
                                                            silent = TRUE)
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
  dat <- sp::SpatialPoints(x[, c(lon, lat)], proj4string = sp::CRS(wgs84))
  limits <- raster::extent(dat) + 1
  ref <- raster::crop(ref, limits)
  
  if (is.null(ref)) {
    out <- rep(TRUE, nrow(x))
  }
  else {
    sp::proj4string(ref) <- wgs84
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


#' @name cc_env_ou
#' @param x, a data.frame containing at least longitude and latitude columns, in the same projection as the predictors
#' @param lat, column name containing decimal or projected latitude
#' @param lon, column name containing decimal or projected longitude
#' @param predictors, raster 
#' @param cols, vector of predictors names to include for outlier test. If NULL, include all layers from predictor raster. 
#' @param threshold, float. Minimal proportion of outlier predictors variables to label an observation as an outlier. E.g. with 
#' 4 predictors and threshold = 0.5, an observation is flagged as an outlier is it is an outlier for 2 or more predictors.
#' @param value a character string defining the output value (clean or flagged). See return.
#' @return df increased by n variables corresponding to the result of the Reverse Jackknife procedure for each tested variable in cols

cc_env_out <- function(presvals,
                       cols = NULL,
                       threshold = 0.8, value = "clean",
                       verbose = TRUE) {
  
  message(sprintf("Testing environmental outliers."))
  if(is.null(cols)) cols <- names(presvals)
  
  nb_var <- floor(threshold * length(cols))
  
  out <- dplyr::select(presvals, all_of(cols)
  ) %>%  dplyr::mutate(dplyr::across(everything(), flag_env_outlier)
  ) %>% dplyr::rename_with(~paste0(.x, "_jn.out")
  ) %>% dplyr::mutate(sumOutl = rowSums(.==FALSE) 
  ) %>% dplyr::mutate(flagged = ifelse(sumOutl >= nb_var, FALSE, TRUE)
  ) %>% dplyr::select(flagged)
  
  nb_flagged <- nrow(out %>% dplyr::filter(flagged == FALSE))
  
  if (verbose) {
    if(value == "clean"){
      message(sprintf("Removed %s records.", nb_flagged))
    }else{
      message(sprintf("Flagged %s records.", nb_flagged))
    }
    
  }
  
  switch(value, clean = return(x[out, ]), flagged = return(out$flagged))
  
}

#' @param x, a vector of values to test with the Reverse Jackknife procedure
#' @return vec, a vector of FALSE for outlier values and TRUE for non-outlier values


flag_env_outlier <- function(x) { 
  vec <- rep(TRUE, length(x))
  vec[rjack(x)] <- FALSE
   return(vec)
 
}

#' @param d, a vector of values to test with the Reverse Jackknife procedure
#' @return a vector of element position considered as outliers
# adapted from https://rdrr.io/cran/biogeo/man/rjack.html

rjack <- function (d) 
{
  xx <- d
  d <- unique(d)
  #rng <- diff(range(d))
  mx <- mean(d)
  n <- length(d)
  n1 <- n - 1
  
  if (n1 > 0) {
    t1 <- (0.95 * sqrt(n)) + 0.2
    x <- sort(d)
    y <- rep(0, n1)
    for (i in 1:n1) {
      x1 <- x[i + 1]
      if (x[i] < mx) {
        y[i] <- (x1 - x[i]) * (mx - x[i])
      }
      else {
        y[i] <- (x1 - x[i]) * (x1 - mx)
      }
    }
    my <- mean(y)
    z <- y / (sqrt(sum((y - my)^2) / n1))
    out <- rep(0, length(xx))
    if (any(z > t1)) {
      f <- which(z > t1)
      v <- x[f]
      if (v < median(x)) {
        xa <- (xx <= v) * 1
        out <- out + xa
      }
      if (v > median(x)) {
        xb <- (xx >= v) * 1
        out <- out + xb
      }
    }
    else {
      out <- out
    }
  } else {
    out <- rep(0, length(xx))
  }
  f <- which(out == 1)
  return(f)
}