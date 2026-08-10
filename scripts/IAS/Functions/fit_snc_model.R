## ------------------------------------------------------
## FUNCTION TO RUN S&C/SAMPLING MODELS
## ------------------------------------------------------ 

### 
#loop through alien::snc model function with specified parameters + catch specific warnings and errors: 
## Hessian warnings = treated as errors
## NaNs produced warnings ignored (example data also produced NaNs) 
## all other warnings treated as warnings

fit_snc_model <- function(model_name, y, data, growth, type, pi) {
  warnings <- character(0)
  error_msg <- NA_character_     # store critical warning or error text
  error_occurred <- FALSE
  
  # Capture and classify warnings
  handler <- function(w) {
    msg <- conditionMessage(w)
    
    # Case 1: Critical Hessian warnings → treat as error
    if (grepl("Hessian matrix inversion", msg, fixed = TRUE) ||
        grepl("Nearest Positive Definite Matrix", msg, fixed = TRUE)) {
      error_occurred <<- TRUE
      error_msg <<- msg
      invokeRestart("muffleWarning")  # suppress display
      return(NULL)
    }
    
    # Case 2: Ignore log(lambda) NaN warnings
    if (grepl("In log\\(lambda\\)", msg, fixed = FALSE) ||
        grepl("NaNs produced", msg, fixed = TRUE)) {
      invokeRestart("muffleWarning")
      return(NULL)
    }
    
    # Case 3: Normal warnings → collect them
    warnings <<- c(warnings, msg)
    invokeRestart("muffleWarning")
  }
  
  # Run model, catching both errors and warnings
  result <- tryCatch(
    withCallingHandlers(
      alien::snc(
        y = y,
        data = data,
        pi = pi,
        mu = ~ time,
        control = list(maxit = 10000),
        growth = growth,
        type = type
      ),
      warning = handler
    ),
    error = function(e) {
      error_occurred <<- TRUE
      error_msg <<- conditionMessage(e)
      return(NA)
    }
  )
  
  # If a Hessian warning/error occurred, treat as NA
  if (isTRUE(error_occurred)) {
    result <- NA
  }
  
  # Check convergence only if the model actually fitted
  # convergence issues will return NA model values
  if (!isTRUE(error_occurred)) {
    
    if (check_convergence(result) == "did not converge") {
      error_occurred <- TRUE
      error_msg <- "did not converge"
      result <- NA
    }
  }
  
  # Save model, warnings, and error messages to global environment
  assign(model_name, result, envir = .GlobalEnv)
  assign(paste0(model_name, "_warnings"), warnings, envir = .GlobalEnv)
  assign(paste0(model_name, "_error"), error_msg, envir = .GlobalEnv)
  
  print(model_name)
}

