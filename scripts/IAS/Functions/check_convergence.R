## ------------------------------------------------------
## CHECK MODEL CONVERGENCE
## ------------------------------------------------------ 

check_convergence <- function(model) {
  
  if (is.null(model) || identical(model, NA)) {
    return("NA")
  }
  
  if (!is.null(model$convergence) && model$convergence == 0) {
    return("converged")
  }
  
  "did not converge"
}
