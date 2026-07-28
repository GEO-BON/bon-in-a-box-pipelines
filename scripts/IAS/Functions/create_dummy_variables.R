## ------------------------------------------------------
## DUMMY VARIBALES FOR ALL MODELS
## ------------------------------------------------------ 

create_dummy_variables <- function(model_names) {
  
  purrr::walk(model_names, function(name) {
    
    assign(paste0(name), NA_character_, envir = .GlobalEnv)
    assign(paste0(name, "_Beta0"), NA_character_, envir = .GlobalEnv)
    assign(paste0(name, "_Beta1"), NA_character_, envir = .GlobalEnv)
    assign(paste0(name, "_bias"), NA_character_, envir = .GlobalEnv)
    assign(paste0(name, "_MSE"), NA_character_, envir = .GlobalEnv)
    assign(paste0(name, "_rsquared"), NA_character_, envir = .GlobalEnv)
    assign(paste0(name, "_AIC"), NA_character_, envir = .GlobalEnv)
    assign(paste0(name, "_z"), NA_character_, envir = .GlobalEnv)
    assign(paste0(name, "_p"), NA_character_, envir = .GlobalEnv)
    assign(paste0(name, "_prob_Beta1_zero"), NA_character_, envir = .GlobalEnv)
    assign(paste0(name, "_meanIAS"), NA_character_, envir = .GlobalEnv)
    assign(paste0(name, "_issue_text"), "not run", envir = .GlobalEnv)
    
    assign(paste0(name), NA_character_, envir = .GlobalEnv)
    assign(paste0(name, "_summary"), NA_character_, envir = .GlobalEnv)
    assign(paste0(name, "_Beta0_out"), NA_real_, envir = .GlobalEnv)
    assign(paste0(name, "_Beta1_out"), NA_real_, envir = .GlobalEnv)
    assign(paste0(name, "_Beta1_SE_out"), NA_real_, envir = .GlobalEnv)
    assign(paste0(name, "_prob_Beta1_zero_out"), NA_character_, envir = .GlobalEnv)
    assign(paste0(name, "_bias_out"), NA_real_, envir = .GlobalEnv)
    assign(paste0(name, "_MSE_out"), NA_real_, envir = .GlobalEnv)
    assign(paste0(name, "_rsquared_out"), NA_real_, envir = .GlobalEnv)
    assign(paste0(name, "_AIC_out"), NA_real_, envir = .GlobalEnv)
    assign(paste0(name, "_z"), NA_real_, envir = .GlobalEnv)
    assign(paste0(name, "_p"), NA_real_, envir = .GlobalEnv)
    assign(paste0(name, "_meanIAS_out"), NA_real_, envir = .GlobalEnv)
    assign(paste0(name, "_meanIAS_SE_out"), NA_real_, envir = .GlobalEnv)
    assign(paste0(name, "_issue_text"), "not run", envir = .GlobalEnv)
    
  })
}
