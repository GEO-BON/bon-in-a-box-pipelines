## ------------------------------------------------------
## FORMAT MODEL SUMMARY STATISTICS
## ------------------------------------------------------ 

# format numeric/stat values
format_stat <- function(value, warn_flag) {
  if (is.na(value)) return(NA_character_)
  
  # Force numeric conversion
  value <- as.numeric(value)
  if (is.na(value)) return(NA_character_)
  
  # Apply scientific notation if very large
  if (abs(value) >= 10000) {
    formatted <- formatC(value, format = "e", digits = 1)
  } else if (abs(value) < 0.01 & abs(value) > 0.001) {
    # Format very small numbers as < 0.0001
    formatted <- format(round(value, 3), nsmall = 3)
  } else if (abs(value) < 0.001) {
    # Format very small numbers as < 0.0001
    formatted <- "< 0.001"
  } else {
    # Round and pad to 2 decimal places
    formatted <- format(round(value, 2), nsmall = 2)
  }
  
  # Append "*" if warnings present
  if (warn_flag) formatted <- paste0(formatted, "*")
  
  return(formatted)
}

