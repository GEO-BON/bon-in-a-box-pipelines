#' @param x, a dataframe of observation containing at least: decimal coordinates into two columns and one unique identifier column 
#' @param lat, column name containing decimal latitude
#' @param lon, column name containing decimal longitude
#' @param tests a vector of character strings, indicating which tests to run. 
#' See details for all tests available. Default = c("capitals", "centroids", 
#' "equal", "gbif", "institutions", "duplicates", "urban",
#' "seas", "zeros"). See parameters of each test at https://github.com/ropensci/CoordinateCleaner/blob/master/R/clean_coordinates.R
#' @param value a character string defining the output value (clean or flagged). See return.
#' @param report logical or character.  If TRUE a report file is written to the
#' directory dir, summarizing the cleaning results. Default = FALSE.
#' @param dir character, directory to write the cleaning results.
#' @return If value == 'clean', a dataframe with problematic observations removed: nrows<= nrows(x)
#' if value == 'flagged', observations dataframe x with a column 'flagged'
#'TRUE = clean coordinate, FALSE = potentially problematic (= at least one test failed).
#' @import CoordinateCleaner
#' @import dplyr


clean_occurrences <- function(x,
                                 id = "id",
                                 lon = "decimallongitude", 
                                 lat = "decimallatitude", 
                                 tests = c( "equal",
                                            "zeros", 
                                            "duplicates", 
                                            "capitals", 
                                            "centroids",
                                            "seas", 
                                            "urban",
                                            "gbif", 
                                            "institutions"
                                            
                                 ),
                                 capitals_rad = 10000,
                                 centroids_rad = 1000, 
                                 centroids_detail = "both", 
                                 inst_rad = 100, 
                                 range_rad = 0,
                                 zeros_rad = 0.5,
                                 capitals_ref = NULL, 
                                 centroids_ref = NULL, 
                                 inst_ref = NULL, 
                                 range_ref = NULL,
                                 seas_ref = NULL, 
                                 seas_scale = 50,
                                 additions = NULL,
                                 urban_ref = NULL,
                                 value = "flagged", 
                                 verbose = TRUE, 
                                 report = FALSE,
                                 dir = getwd()) {
  # check function arguments
  match.arg(value, choices = c("flagged", "clean"))
  match.arg(centroids_detail, choices = c("both", "country", "provinces"))
  
  
  # check column names
  nams <- c(id, lon, lat, "species")
  if (!all(nams %in% names(x))) {
    stop(sprintf("%s column not found\n", nams[which(!nams %in% names(x))]))
  }
  
  # Initiate output 
  out <- data.frame(matrix(NA, nrow = nrow(x), ncol = 10))
  colnames(out) <- c( "val", "equ", "zer", "dpl","cap", "cen", "sea", "urb",
                      "gbf", "inst")
  
  # Run tests Validity, check if coordinates fit to lat/long system, this has
  # to be run all the time, as otherwise the other tests don't work
  out$val <- cc_val(x, lon = lon, lat = lat, 
                    verbose = verbose, value = "flagged")
  
  if (!all(out$val)) {
    stop(
      "invalid coordinates found in rows, clean dataset before proceeding:\n",
      paste(which(!out$val), "\n")
    )
  }
  
  ## Equal coordinates
  if ("equal" %in% tests) {
    out$equ <- cc_equ(x,
                      lon = lon, lat = lat, verbose = verbose, value = "flagged",
                      test = "absolute"
    )
  }
  
  ## Zero coordinates
  if ("zeros" %in% tests) {
    out$zer <- cc_zero(x,
                       lon = lon, lat = lat, buffer = zeros_rad, verbose = verbose,
                       value = "flagged"
    )
  }
  
  ## Duplicates
  if ("duplicates" %in% tests) {
    out$dup <-cc_dupl(x, lon = lon, lat = lat, additions = additions,
                      value = "flagged")
    
  }
  
  
  
  ## Capitals
  if ("capitals" %in% tests) {
    out$cap <- cc_cap(x,
                      lon = lon, lat = lat, buffer = capitals_rad, ref = capitals_ref,
                      value = "flagged", verbose = verbose
    )
  }
  
  ## Centroids
  if ("centroids" %in% tests) {
    out$cen <- cc_cen(x,
                      lon = lon, lat = lat, buffer = centroids_rad, test = centroids_detail,
                      ref = countryref, value = "flagged", verbose = verbose
    )
  }
  
  ## Seas
  if ("seas" %in% tests) {
    out$sea <- cc_sea(x,
                      lon = lon, lat = lat, ref = seas_ref, 
                      scale = seas_scale,
                      verbose = verbose,
                      value = "flagged"
    )
  }
  
  ## Urban Coordinates
  if ("urban" %in% tests) {
    out$urb <- cc_urb(x,
                      lon = lon, lat = lat, ref = urban_ref, verbose = verbose,
                      value = "flagged"
    )
  }
  
  ## GBIF headquarters
  if ("gbif" %in% tests) {
    out$gbf <- cc_gbif(x, lon = lon, lat = lat, 
                       verbose = verbose, value = "flagged")
  }
  
  ## Biodiversity institution
  if ("institutions" %in% tests) {
    out$inst <- cc_inst(x,
                        lon = lon, lat = lat, ref = inst_ref, buffer = inst_rad,
                        verbose = verbose, value = "flagged"
    )
  }
  
  
  # prepare output data
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
  
  ret <- data.frame(dplyr::select(x, all_of(c(id, lon, lat))), out, summary = suma)
  names(ret) <- c(c(id, lon, lat),
                  paste(".", names(out), sep = ""),
                  ".summary")
  
  
  repo <- bind_cols(out %>%
                      summarise(across(everything(), ~ length(suma) - sum(.x, na.rm = TRUE))),
                    nb_init = length(suma),
                    nb_flagged = sum(!suma,
                                     na.rm = TRUE
                    ),
                    EQ = round(
                      sum(!suma, na.rm = TRUE) / length(suma), 2
                    ))
  
  
  if (report) {
    report <- paste0(dir, "/clean_coordinates_report.csv")
    flag_occ <- paste0(dir, "/flagg_occ.csv")
  }
  if (is.character(report)) {
    write.table(repo, report, sep = ";", row.names = FALSE, quote = FALSE)
    write.table(ret, flag_occ , sep = ";", row.names = FALSE, quote = FALSE)  
    message(sprintf("Cleaning report saved in %s.", report))
    message(sprintf("Flagged occurrences saved in %s.", flag_occ))
    
  }
  
  
  if (value == "clean") {
    out <- x[suma, ]
  }
  if (value == "flagged") {
    out <- bind_cols(x, flagged = suma)
    
    
  }
  return(out)
}
