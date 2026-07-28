## ------------------------------------------------------
## SUMMARISE S&C/SAMPLING/CONSTANT DETECTION MODEL FIT STATISTICS
## ------------------------------------------------------ 

summarise_snc_models <- function() {
  
  model_names <- if (decision == "model all") {c("ConstDet", "SC", "Sampling")} else if (decision == "model subset") {c("ConstDet", "Sampling")}
  
  model_summary <- purrr::map_dfr(model_names, function(name) {
    
    model <- tryCatch(get(name, envir = .GlobalEnv), error = function(e) NULL)
    warn_name <- paste0(name, "_warnings")
    error_name <- paste0(name, "_error")
    warnings <- tryCatch(get(warn_name, envir = .GlobalEnv), error = function(e) character(0))
    errors <- tryCatch(get(error_name, envir = .GlobalEnv), error = function(e) character(0))
    warn_flag <- length(warnings) > 0

    
    # Create NAs for models that produced errors: 
    if (is.null(model) || all(is.na(model))) {
      
      assign(paste0(name, "_AIC"), NA_character_, envir = .GlobalEnv)
      assign(paste0(name, "_MSE"), NA_character_, envir = .GlobalEnv)
      assign(paste0(name, "_bias"), NA_character_, envir = .GlobalEnv)
      assign(paste0(name, "_Beta0"), NA_character_, envir = .GlobalEnv)
      assign(paste0(name, "_Beta1"), NA_character_, envir = .GlobalEnv)
      assign(paste0(name, "_prob_Beta1_zero"), NA_character_, envir = .GlobalEnv)
      assign(paste0(name, "_meanIAS"), NA_character_, envir = .GlobalEnv)
      
      assign(paste0(name, "_AIC_out"), NA_real_, envir = .GlobalEnv)
      assign(paste0(name, "_MSE_out"), NA_real_, envir = .GlobalEnv)
      assign(paste0(name, "_bias_out"), NA_real_, envir = .GlobalEnv)
      assign(paste0(name, "_Beta0_out"), NA_real_, envir = .GlobalEnv)
      assign(paste0(name, "_Beta1_out"), NA_real_, envir = .GlobalEnv)
      assign(paste0(name, "_Beta1_SE_out"), NA_real_, envir = .GlobalEnv)
      assign(paste0(name, "_prob_Beta1_zero_out"), NA_character_, envir = .GlobalEnv)
      assign(paste0(name, "_meanIAS_out"), NA_real_, envir = .GlobalEnv)
      assign(paste0(name, "_meanIAS_SE_out"), NA_real_, envir = .GlobalEnv)
      
      error_text <- paste0(substr(errors[1], 1, 20), ifelse(nchar(errors[1]) > 20, "...", ""))
      assign(paste0(name, "_issue_text"), error_text, envir = .GlobalEnv)
      
      return(tibble::tibble(
        model_name = name,
        AIC = NA_character_,
        Convergence = "NA",
        Issues = error_text
      ))
    }
    
    
    # --- Convergence ---
    convergence <- check_convergence(model)
    
    # Create NAs for models that did not converge
    if (convergence == "did not converge") {
      
      assign(paste0(name, "_AIC"), NA_character_, envir = .GlobalEnv)
      assign(paste0(name, "_MSE"), NA_character_, envir = .GlobalEnv)
      assign(paste0(name, "_bias"), NA_character_, envir = .GlobalEnv)
      assign(paste0(name, "_Beta0"), NA_character_, envir = .GlobalEnv)
      assign(paste0(name, "_Beta1"), NA_character_, envir = .GlobalEnv)
      assign(paste0(name, "_prob_Beta1_zero"), NA_character_, envir = .GlobalEnv)
      assign(paste0(name, "_meanIAS"), NA_character_, envir = .GlobalEnv)
      
      assign(paste0(name, "_AIC_out"), NA_real_, envir = .GlobalEnv)
      assign(paste0(name, "_MSE_out"), NA_real_, envir = .GlobalEnv)
      assign(paste0(name, "_bias_out"), NA_real_, envir = .GlobalEnv)
      assign(paste0(name, "_Beta0_out"), NA_real_, envir = .GlobalEnv)
      assign(paste0(name, "_Beta1_out"), NA_real_, envir = .GlobalEnv)
      assign(paste0(name, "_Beta1_SE_out"), NA_real_, envir = .GlobalEnv)
      assign(paste0(name, "_prob_Beta1_zero_out"), NA_character_, envir = .GlobalEnv)
      assign(paste0(name, "_meanIAS_out"), NA_real_, envir = .GlobalEnv)
      assign(paste0(name, "_meanIAS_SE_out"), NA_real_, envir = .GlobalEnv)
      
      error_text <- paste0("convergence failed")
      assign(paste0(name, "_issue_text"), error_text, envir = .GlobalEnv)
      
      return(tibble::tibble(
        model_name = name,
        AIC = NA_character_,
        Convergence = "did not converge",
        Issues = error_text
      ))
    }
    
    
    # For models that didn't produce errors: 
    ## -----------------------------
    ## summary calculations
    ## -----------------------------
    
    
    # --- AIC ---
    n_params <- nrow(model$coefficients)
    ll <- suppressWarnings(model$`log-likelihood`)
    ## ALIEN R PACKAGE CODE outputs the minimised negative LL rather than the maximised LL - to calculate AIC, formula switches from - to + 
    ## AIC = 2 * k + 2 * (minimised Neg LL)
    AIC_val <- if (is.numeric(ll)) (2 * n_params) + (2 * ll) else NA_real_
    AIC_fmt  <- format_stat(AIC_val, warn_flag)
    assign(paste0(name, "_AIC"), AIC_fmt, envir = .GlobalEnv)
    assign(paste0(name, "_AIC_out"), AIC_val, envir = .GlobalEnv)
    
    # --- MSE ---
    MSE_val <- tryCatch(
      Metrics::mse(model$records, model$fitted.values),
      error = function(e) NA_real_
    )
    MSE_fmt  <- format_stat(MSE_val, warn_flag)
    assign(paste0(name, "_MSE"), MSE_fmt, envir = .GlobalEnv)
    assign(paste0(name, "_MSE_out"), MSE_val, envir = .GlobalEnv)
    
    # --- Bias ---
    Bias_val <- tryCatch({
      mean(model$records - model$fitted.values)
    }, error = function(e) NA_real_)
    Bias_fmt <- format_stat(Bias_val, warn_flag)
    assign(paste0(name, "_bias"), Bias_fmt, envir = .GlobalEnv)
    assign(paste0(name, "_bias_out"), Bias_val, envir = .GlobalEnv)
    
    # --- Beta0 ---
    Beta0_val <- tryCatch({
      est <- alien::summary_snc(model)[1, 1]
      est
    }, error = function(e) NA_real_)
    Beta0_fmt <- format_stat(Beta0_val, warn_flag)
    assign(paste0(name, "_Beta0"), Beta0_fmt, envir = .GlobalEnv)
    assign(paste0(name, "_Beta0_out"), Beta0_val, envir = .GlobalEnv)
    
    # --- Beta1 ---
    Beta1_fmt <- tryCatch({
      est <- alien::summary_snc(model)[2, 1]
      err <- alien::summary_snc(model)[2, 2]
      paste0(format_stat(est, warn_flag), " (", formatC(err, format = "f", digits = 3), ")")
    }, error = function(e) NA_character_)
    assign(paste0(name, "_Beta1"), Beta1_fmt, envir = .GlobalEnv)
    Beta1_val <- tryCatch({alien::summary_snc(model)[2, 1]}, error = function(e) NA_real_)
    Beta1_SE_val <- tryCatch({alien::summary_snc(model)[2, 2]}, error = function(e) NA_real_)
    assign(paste0(name, "_Beta1_out"), Beta1_val, envir = .GlobalEnv)
    assign(paste0(name, "_Beta1_SE_out"), Beta1_SE_val, envir = .GlobalEnv)
    
    # --- probability of Beta1 being 0 ---
    prob_Beta1_zero_val <- tryCatch({
      alien::summary_snc(model)[2, 3]
    }, error = function(e) NA_character_)
    prob_Beta1_zero_fmt <- format_stat(prob_Beta1_zero_val, warn_flag)
    assign(paste0(name, "_prob_Beta1_zero"), prob_Beta1_zero_fmt, envir = .GlobalEnv)
    assign(paste0(name, "_prob_Beta1_zero_out"), prob_Beta1_zero_val, envir = .GlobalEnv)
    
    # --- meanIAS ---
    mean_val <- tryCatch(mean(model$fitted.values), error = function(e) NA_real_)
    sd_val <- tryCatch(sd(model$fitted.values), error = function(e) NA_real_)
    meanIAS_val <- if (is.na(mean_val)) NA_character_ else {
      paste0(format_stat(mean_val, warn_flag), " (", formatC(sd_val, format = "f", digits = 2), ")")
    }
    assign(paste0(name, "_meanIAS"), meanIAS_val, envir = .GlobalEnv)
    assign(paste0(name, "_meanIAS_out"), mean_val, envir = .GlobalEnv)
    assign(paste0(name, "_meanIAS_SE_out"), sd_val, envir = .GlobalEnv)
    
    ##-------------------
    issue_text <- if (length(warnings) > 0) {
      paste0(substr(warnings[1], 1, 20), ifelse(nchar(warnings[1]) > 20, "...", ""))
    } else {
      NA_character_
    }
    assign(paste0(name, "_issue_text"), issue_text, envir = .GlobalEnv)
    
    tibble::tibble(
      model_name = name,
      AIC = AIC_fmt,
      Convergence = convergence,
      Issues = issue_text
    )
  })
  
  model_summary <- dplyr::left_join(get("param_grid", envir = .GlobalEnv), model_summary, by = "model_name") %>%
    dplyr::relocate(model_name)
  
  assign(paste0("SNC_model_summary"), model_summary, envir = .GlobalEnv)
  
  print(model_summary)
}