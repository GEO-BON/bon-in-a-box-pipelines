## ------------------------------------------------------
## Script name: Model + Collate Outputs
##
## Purpose of script: This script produces IAS rate models 
## + packages model outputs into plots + tables 
##
## Author: Rachel Mason
##
## Date Created: 2025-10-07
## ------------------------------------------------------
## ------------------------------------------------------

## NOTE: This script should be run from the P6_runWorkflow.R script

#arrange country list in alphabetical order + pre-create vector list for outputs
Countries <- input$ISO3
datalist <- vector("list", length = length(Countries))

## ------------------------------------------------------
## ADD REQUIRED FUNCTIONS TO GLOBAL ENVIRONMENT
## ------------------------------------------------------

source(file.path("scripts/IAS","Functions","plot_comp_all.R"))
source(file.path("scripts/IAS","Functions","plot_qual_raw.R"))
source(file.path("scripts/IAS","Functions","create_dummy_variables.R"))
source(file.path("scripts/IAS","Functions","summarise_snc_models.R"))
source(file.path("scripts/IAS","Functions","check_convergence.R"))
source(file.path("scripts/IAS","Functions","format_stat.R"))
source(file.path("scripts/IAS","Functions","run_covariate_glm.R"))
source(file.path("scripts/IAS","Functions","fit_snc_model.R"))
## ------------------------------------------------------
## LOOP THROUGH ALL COUNTRIES
## ------------------------------------------------------ 

for (i in seq_along(Countries)) {
  
  
  ## Clear any existing country's model objects
  rm(list=ls(pattern = "^SNC"))
  rm(list=ls(pattern = "^p[0-9]+$"))
  rm(list=ls(pattern = "^naive_"))
  rm(list=ls(pattern = "^covariate_"))
  
  
  x <- Countries[[i]]
  CountryName <- countrycode::countrycode(x, origin = "iso3c", destination = "country.name")
  
  ## ------------------------------------------------------
  ## LOAD REQUIRED DATA
  ## ------------------------------------------------------ 
  
  # Copy and load .csv integrated IAS data file from P5
  IntegratedData <- input$IntegratedData
  
  # Copy and load .rds covariate data file from P5 - SQL method file 
  CovariateData <- input$CovariateData
  
  ### OR this is where you could use occ_download_get with existing GBIF covariate download keys to load in existing downloaded data 
  ### e.g. survey effort proxy data for JAPAN - doi is https://doi.org/10.15468/dl.3f9a3e, download key is (0030163-251009101135966) 
  
  # CovariateDownload <- occ_download_get(key = "0030163-251009101135966", path = ".", overwrite = TRUE)
  # CovariateData <- occ_download_import(CovariateDownload) %>%
  #   filter(year <= 2020)
  
  ## --------------------------------------------------------------------------
  ## DATA REORGANISATION - Create time series data frame from full species list
  ## -------------------------------------------------------------------------- 
  
  # Filter to only species on GRIIS checklist, filter out records with no dates or dates pre-1970 or post-2020
  # NOTE: this filtering may need to be adjusted to include user-supplied species data while still excluding 
  # species that are only listed on the SInAS/First Records dataset 
  isInvasiveAnywhere <- IntegratedData %>% dplyr::filter(grepl("G",linkID)) %>% 
    dplyr::filter(eventDate >= 1970) %>% 
    dplyr::filter(eventDate <= 2020) %>%
    dplyr::filter(isInvasiveAnywhere == "TRUE") %>%
    dplyr::count(eventDate) %>% 
    dplyr::rename(year = eventDate) %>% 
    tidyr::complete(year = 1970:2020)
  
  isInvasiveAnywhere$time = (isInvasiveAnywhere$year - 1970)
  isInvasiveAnywhere$n[is.na(isInvasiveAnywhere$n)] <- 0
  isInvasiveAnywhere$n <- as.numeric(isInvasiveAnywhere$n)
  
  ## --------------------------------------------------------------------------
  ## Link time series data frame to sampling effort proxy data 
  ## -------------------------------------------------------------------------- 
  
  #(sorry for the dumb names of these data frames, but they are everywhere in all the code now so unfortunately I haven't changed them) 
  input_Anywhere <- left_join(isInvasiveAnywhere, CovariateData, by = "year")
  input_Anywhere$recordscount[is.na(input_Anywhere$recordscount)] <- 0
  input_Anywhere$recordscount <- as.numeric(input_Anywhere$recordscount)
  
  ## scale covariate data (requirement for using it in the SnC models)
  input_Anywhere <- dplyr::mutate(input_Anywhere, scale_recordscount = scale(recordscount))
  
  
  ## --------------------------------------------------------------------------
  ## MODELLING DECISION - Define modelling approach based on data sparsity etc.
  ## -------------------------------------------------------------------------- 
  
  ## CRITERIA 1 - FIRST RECORD COMPLETENESS 
  
  #total number of species from GRIIS list considered isInvasiveAnywhere
  allIAS <- IntegratedData %>% 
    # filter for species on original GRIIS list for country (i.e. filter out species ONLY from the first records/SInAS database (which includes some native species))
    dplyr::filter(grepl("GRIIS", origDB)) %>% 
    # filter for only species considered InvasiveAnywhere
    dplyr::filter(grepl("TRUE", isInvasiveAnywhere))
  
  #number of species from GRIIS list considered isInvasiveAnywhere that also have a First Record date
  IASWithFirstRecords <- IntegratedData %>% 
    # filter for species on original GRIIS list for country (i.e. filter out species ONLY from the first records/SInAS database (which includes some native species))
    dplyr::filter(grepl("GRIIS", origDB)) %>% 
    # filter for only species considered InvasiveAnywhere
    dplyr::filter(grepl("TRUE", isInvasiveAnywhere)) %>% 
    # filter out species with no/unknown first record
    dplyr::filter(!is.na(eventDate))
  
  firstRecordCompleteness = (nrow(IASWithFirstRecords)/nrow(allIAS))*100
  
  ## CRITERIA 2 - NON-ZERO YEARS
  
  nonZeroYears <- input_Anywhere %>%
    filter(n != 0) %>%
    nrow()
  
  ## Modelling decision framework for combinations of criteria 1 and criteria 2 
  
  decisionCriteria = data.frame(
    ModellingDecisions = c("NonZeroYears_<10", "NonZeroYears_10to15", "NonZeroYears_15to25", "NonZeroYears_>25"), 
    firstRecordComp_50to100pcnt = c("Too data sparse to model IAS rate", "Qualitative approach", "Model subset of models (excluding S&C)", "Model all model options"), 
    firstRecordComp_25to50pcnt = c("Too data sparse to model IAS rate", "Qualitative approach", "Model subset of models (excluding S&C), but interpret with caution", "Model all model options, but interpret with caution"), 
    firstRecordComp_0to25pcnt = c("Too data sparse to model IAS rate", "Too data sparse to model IAS rate", "Qualitative approach", "Qualitative approach")
  )
    
  view(decisionCriteria)
  
  # modelling decision for the data based on modelling criteria outlined in table above
  # will impact the approach taken for each country's data based on how criteria are met 
  modellingDecision <- if (nonZeroYears >= 25 & firstRecordCompleteness >= 25) {"model all" 
  } else if (nonZeroYears >= 15 & nonZeroYears < 25 & firstRecordCompleteness >= 25) {"model subset" 
  } else if (nonZeroYears >= 15 & firstRecordCompleteness < 25) {"qualitative" 
  } else if (nonZeroYears >= 10 & nonZeroYears < 15 & firstRecordCompleteness >= 25) {"qualitative"
  } else {"nothing"}
  
  # logical flag for results requiring a note about low first records completeness potentially 
  # impacting the quality and surety in the model results - results where interpretationFlag == TRUE 
  # should be flagged to be interpreted with caution 
  interpretationFlag <- if (nonZeroYears >= 15 & firstRecordCompleteness >= 50) {FALSE 
  } else if (nonZeroYears >= 15 & firstRecordCompleteness >= 25 & firstRecordCompleteness < 50) {TRUE
  } else {FALSE}
  
  if (interpretationFlag == TRUE) {
    cli::cli_alert_warning("A large number of species in the country checklist do not have a date 
                           of establishment (First Record). This may impact the quality of the 
                           data modelling, and therefore results must be interpreted with caution.")
  }
  
  decision <<- modellingDecision
  
  
  modellingDecision_Formatted<- if (modellingDecision == "model all") {"Model all model options"
  } else if (modellingDecision == "model subset") {"Model subset of models (excluding S&C)"
  } else if (modellingDecision == "qualitative") {"Qualitative approach"
  } else if (modellingDecision == "qualitative") {"qualitative"
  } else {"Too data sparse to model IAS rate"}
  
  
  ### NOTE - data summary table below is optional, this code outputs a HTML table of some of 
  ### the basic summary stats 
  
  ## ------------------------------------------------------
  ## DATA SUMMARY TABLE
  ## ------------------------------------------------------
  
  ## COV numbers 1970-2020: 
  covariateRecords = CovariateData %>% filter(year >= 1970 & year <= 2020)
  totalCovariateRecords = sum(covariateRecords$recordscount)
  
  ## IAS numbers: 
  
  GRIIS_ONLY <- IntegratedData %>% dplyr::filter(grepl("GRIIS", origDB))
  
  totalGRIISSpecies <- GRIIS_ONLY %>% nrow() #1
  
  totalInvasiveSpecies <- GRIIS_ONLY %>% dplyr::filter(grepl("TRUE", isInvasiveAnywhere)) %>% nrow() #2
  
  IASAnimals = GRIIS_ONLY %>% 
    dplyr::filter(grepl("TRUE", isInvasiveAnywhere)) %>%
    dplyr::filter(kingdom == "Animalia") %>% nrow() #3
  
  IASPlants = GRIIS_ONLY %>% 
    dplyr::filter(grepl("TRUE", isInvasiveAnywhere)) %>%
    dplyr::filter(kingdom == "Plantae") %>% nrow() #4
  
  IAS_withFR = GRIIS_ONLY %>% 
    dplyr::filter(grepl("TRUE", isInvasiveAnywhere)) %>% 
    dplyr::filter(!is.na(eventDate)) %>% nrow()
  
  IAS_withFR_1970_2020 = GRIIS_ONLY %>% 
    dplyr::filter(grepl("TRUE", isInvasiveAnywhere)) %>% 
    dplyr::filter(!is.na(eventDate)) %>% 
    dplyr::filter(eventDate >= 1970 & eventDate <= 2020) %>% nrow() #6
  
  
  ## Gather
  summary <- tibble(
    Variable = c("Number of Alien Species on GRIIS Checklist",
                 "Number of Invasive Alien Species (IAS)",
                 "IAS Plants",
                 "IAS Animals",
                 "Total IAS with First Record Dates", 
                 "IAS with First Record Dates 1970-2020",
                 "First Record Completeness",
                 "Non-Zero Data Years", 
                 "Modelling Decision", 
                 "Survey Effort Proxy Records"),
    "{x}" := c(totalGRIISSpecies,
               totalInvasiveSpecies,
               IASPlants,
               IASAnimals,
               IAS_withFR,
               IAS_withFR_1970_2020, 
               round(firstRecordCompleteness,2),
               nonZeroYears, 
               modellingDecision_Formatted, 
               totalCovariateRecords))
  
  data_summary_table <- gt::gt(summary[1:2]) %>%
    gt::tab_options(column_labels.hidden = TRUE) %>% 
    gt::tab_header(
      title = gt::md(paste0("**","Data Summary: ", CountryName," (",x,")","**"))) 
  
  ## Save summary table
  #gt::gtsave(data_summary_table, file.path(workingDirectory,subDirectory,"Output",x,"Modelled IAS Rates",paste0(x,"_Data_Summary_Table.html")))
  
  
  
  ## ------------------------------------------------------
  ## ------------------------------------------------------
  ## ------------------------------------------------------
  ## ----- modellingDecision = Model all four models  -----
  ## ------------------------------------------------------ 
  ## ------------------------------------------------------
  ## ------------------------------------------------------
  
  
  if (decision == "model all") { 
    
    cli::cli_alert_info("Model Decision = Model all options, running all models now")
    
    ## ------------------------------------------------------
    ## MODEL 1 - SURVEY EFFORT GLM 
    ## ------------------------------------------------------ 
    
    run_covariate_glm()
    
    covariate_summary <- summary(covariate_glm)
    
    ## no stats reported for this model, it's just for fitting a visual line in the qualitative approach plot 
    
    ## ------------------------------------------------------
    ## MODEL 2 - NAIVE POISSON GLM (NAIVE MODEL)
    ## ------------------------------------------------------ 
    naive_glm <- glm(n ~ time, data = input_Anywhere, family = "poisson")
    naive_summary <- summary(naive_glm)
    
    ## --- Naive Summary Stats ---
    naive_Beta0 <- format_stat(coef(naive_summary)[1, 1], FALSE)
    naive_Beta1 <- paste0(format_stat(naive_summary$coefficients[2, 1], FALSE), " (", format_stat(naive_summary$coefficients[2,2], FALSE), ")")
    naive_bias <- format_stat(mean(input_Anywhere$n - predict(naive_glm, type = "response")), FALSE)
    naive_MSE <- format_stat(mean((input_Anywhere$n - predict(naive_glm, type = "response"))^2), FALSE)
    naive_rsquared <- format_stat(1 - (naive_summary$deviance / naive_summary$null.deviance), FALSE)
    naive_AIC <- format_stat(naive_summary$aic, FALSE)
    naive_z <- format_stat(coef(naive_summary)[2, 3], FALSE)
    naive_p <- format_stat(coef(naive_summary)[2, 4], FALSE)
    naive_meanIAS <- paste0(format_stat(mean(fitted(naive_glm)), FALSE), " (", format_stat(sd(fitted(naive_glm)), FALSE), ")")
    
    
    ## --------------------------------------------------------------
    ## MODEL 3-5 - S&C MODEL, CONSTANT DETECTION MODEL & SAMPLING MODEL
    ## --------------------------------------------------------------
    
    ### INFO: 
    ## models have either 3, 4 or 5 parameters being maximised by the likelihood estimation function
    
    ## Parameters input to snc function are: 
    ## y = number of new IAS i.e. IAS time series data
    ## growth/γ2 = population growth parameter (included (set to TRUE) as a parameter in the S&C model, but is not included in the Sampling or Constant Detection models)
    ## pi = Predictors for detection probability Πst - changing this parameters defines whether
    ## the model takes the form of the S&C model, the Constant Detection model, or the Sampling model. 
    
    ## Optional parameter specification not adjusted for this analysis: 
    ## mu = Predictors for annual introduction rate µt (defaults to time if not specified, as for all model specifications tested for this analysis))
    
    # set up parameter grid
    
    param_grid <- tibble(
      growth = c(FALSE, TRUE, FALSE),
      pi = c(~1, ~ time, ~ scale_recordscount)
    )
    
    param_grid$idx <- seq_len(nrow(param_grid))
    param_grid$model_name <- c("ConstDet", "SC", "Sampling")
    
    purrr::pwalk(
      .l = param_grid,
      .f = function(growth, pi, idx, model_name) {
        
        fit_snc_model(
          model_name = model_name,
          y = input_Anywhere$n,
          data = input_Anywhere,
          growth = growth,
          pi = pi,
          type = "exponential"
        )
      }
    )
    
    # summarise_snc_models()
    # 
    # SNC_model_summary
    
    
    ## ------------------------------------------------------
    ## PLOTS OF MODELS - QUALITATIVE APPROACH (SURVEY EFFORT + NAIVE)
    ## ------------------------------------------------------ 
    
    p1 <- plot_qual_raw()
    
    p1.title <- p1 + patchwork::plot_annotation(title = paste0("Qualitative Model Plot: ",CountryName," (",x,")"))
    ggplot2::ggsave(filename = paste0(x,"_qualitative.png"), plot = p1.title, bg = "white", path = (paste0(workingDirectory, "/", subDirectory, "/", "Output/",x,"/Modelled IAS Rates/")), width = 6, height = 4, units = "in")
    
    ## ------------------------------------------------------
    ## PLOTS OF MODELS - COMPARATIVE APPROACH (NAIVE + S&C + SAMPLING + CONSTANT DETECTION)
    ## ------------------------------------------------------ 
    
    p2 <- plot_comp_all()
    
    p2.title <- p2 + patchwork::plot_annotation(title = paste0("Best Fit Model Plots: ",CountryName," (",x,")"))
    ggplot2::ggsave(filename = paste0(x,"_quantitative.png"), plot = p2.title, bg = "white", path = (paste0(workingDirectory, "/", subDirectory, "/", "Output/",x,"/Modelled IAS Rates/")), width = 6, height = 4, units = "in")
  
   
    ## ------------------------------------------------------
    ## ------------------------------------------------------
    ## ------------------------------------------------------
    ## ---- modellingDecision = Model subet, no S&C model ---
    ## ------------------------------------------------------ 
    ## ------------------------------------------------------
    ## ------------------------------------------------------
    
    
  } else if (decision == "model subset") {
    
    #Same as above but only no options to include extra growth parameter due to data sparcity/need to reduce model complexity
    cli::cli_alert_info("Model Decision = Model subset of modelling options, running subset now")
    
    ## ------------------------------------------------------
    ## MODEL 1 - SURVEY EFFORT NEG.BIN GLM 
    ## ------------------------------------------------------ 
    
    run_covariate_glm()
    
    covariate_summary <- summary(covariate_glm)
    
    ## no stats reported for this model, it's just for fitting a visual line in the qualitative approach plot 
    
    ## ------------------------------------------------------
    ## MODEL 2 - NAIVE POISSON GLM (NAIVE MODEL)
    ## ------------------------------------------------------ 
    naive_glm <- glm(n ~ time, data = input_Anywhere, family = "poisson")
    naive_summary <- summary(naive_glm)
    
    ## --- Naive Summary Stats ---
    naive_Beta0 <- format_stat(coef(naive_summary)[1, 1], FALSE)
    naive_Beta1 <- paste0(format_stat(naive_summary$coefficients[2, 1], FALSE), " (", format_stat(naive_summary$coefficients[2,2], FALSE), ")")
    naive_bias <- format_stat(mean(input_Anywhere$n - predict(naive_glm, type = "response")), FALSE)
    naive_MSE <- format_stat(mean((input_Anywhere$n - predict(naive_glm, type = "response"))^2), FALSE)
    naive_rsquared <- format_stat(1 - (naive_summary$deviance / naive_summary$null.deviance), FALSE)
    naive_AIC <- format_stat(naive_summary$aic, FALSE)
    naive_z <- format_stat(coef(naive_summary)[2, 3], FALSE)
    naive_p <- format_stat(coef(naive_summary)[2, 4], FALSE)
    naive_meanIAS <- paste0(format_stat(mean(fitted(naive_glm)), FALSE), " (", format_stat(sd(fitted(naive_glm)), FALSE), ")")
    
    
    ## ---------------------------------------------------------------------------------------------
    ## MODEL 3-4 - CONSTANT DETECTION & BUBA SAMPLING MODEL (WITH COVARIATE)
    ## ---------------------------------------------------------------------------------------------
    ### INFO: 
    ## models have either 3 or 4 parameters being maximised by the likelihood estimation function
    
    ## Parameters input to snc function are: 
    ## y = number of new IAS i.e. IAS time series data
    ## growth/γ2 = set to FALSE so as not to include gamma 2 param in constant detection or sampling model structures
    ## pi = Predictors for detection probability Πst - changing this parameters defines whether
    ## the model takes the the Constant Detection model (~1), or the Sampling (~survey effort proxy) model. 
    
    ## Optional parameter specification not adjusted for this analysis: 
    ## mu = Predictors for annual introduction rate µt (defaults to time if not specified, as for all model specifications tested for this analysis))
    
    # set up parameter grid
    param_grid <- tibble(
      growth = c(FALSE, FALSE),
      pi = c(~ 1, ~ scale_recordscount)
    )
    
    param_grid$idx <- seq_len(nrow(param_grid))
    param_grid$model_name <- c("ConstDet", "Sampling")
    
    purrr::pwalk(
      .l = param_grid,
      .f = function(growth, pi, idx, model_name) {
        
        fit_snc_model(
          model_name = model_name,
          y = input_Anywhere$n,
          data = input_Anywhere,
          growth = growth,
          pi = pi,
          type = "exponential"
        )
      }
    )
    
    # summarise_snc_models()
    # 
    # SNC_model_summary
    
    
    ## ------------------------------------------------------
    ## PLOTS OF MODELS - QUALITATIVE APPROACH (SURVEY EFFORT + NAIVE)
    ## ------------------------------------------------------ 
    
    p1 <- plot_qual_raw()
    
    p1.title <- p1 + patchwork::plot_annotation(title = paste0("Qualitative Model Plot: ",CountryName," (",x,")"))
    ggplot2::ggsave(filename = paste0(x,"_qualitative.png"), plot = p1.title, bg = "white", path = (paste0(workingDirectory, "/", subDirectory, "/", "Output/",x,"/Modelled IAS Rates/")), width = 6, height = 4, units = "in")
    
    ## ------------------------------------------------------
    ## PLOTS OF MODELS - COMPARATIVE APPROACH (NAIVE + SAMPLING + CONSTANT DETECTION)
    ## ------------------------------------------------------ 
    
    p2 <- plot_comp_all()
    
    p2.title <- p2 + patchwork::plot_annotation(title = paste0("Best Fit Model Plots: ",CountryName," (",x,")"))
    ggplot2::ggsave(filename = paste0(x,"_quantitative.png"), plot = p2.title, bg = "white", path = (paste0(workingDirectory, "/", subDirectory, "/", "Output/",x,"/Modelled IAS Rates/")), width = 6, height = 4, units = "in")
    
    
    ## ------------------------------------------------------
    ## DUMMY VARIBALES FOR MISSING MODELS
    ## ------------------------------------------------------ 
    
    ### this is so the table creation for the parameters at the end runs/doesn't return errors 
    ### saying a bunch of parameters are missing when looping through multiple countries, but 
    ### maybe not necessary when only doing one country? 
    
    create_dummy_variables("SC")
    
    ## ------------------------------------------------------
    ## ------------------------------------------------------
    ## ------------------------------------------------------     
    ## ------ modellingDecision = Qualitative Approach ------
    ## ------------------------------------------------------
    ## ------------------------------------------------------
    ## ------------------------------------------------------ 
    
    
  } else if (decision == "qualitative") {
    
    #Same as above but only naive and survey effort models run + plotted/outputted
    cli::cli_alert_warning("Model Decision = Qualitative - Plotting qualitative outputs only.")
    
    ## ------------------------------------------------------
    ## MODEL 1 - SURVEY EFFORT NEG.BIN GLM 
    ## ------------------------------------------------------ 
    
    run_covariate_glm()
    
    covariate_summary <- summary(covariate_glm)
    
    ## no stats reported for this model, it's just for fitting a visual line in the qualitative approach plot 
    
    ## ------------------------------------------------------
    ## MODEL 2 - NAIVE POISSON GLM (NAIVE MODEL)
    ## ------------------------------------------------------ 
    naive_glm <- glm(n ~ time, data = input_Anywhere, family = "poisson")
    naive_summary <- summary(naive_glm)
    
    ## --- Naive Summary Stats ---
    naive_Beta0 <- format_stat(coef(naive_summary)[1, 1], FALSE)
    naive_Beta1 <- paste0(format_stat(naive_summary$coefficients[2, 1], FALSE), " (", format_stat(naive_summary$coefficients[2,2], FALSE), ")")
    naive_bias <- format_stat(mean(input_Anywhere$n - predict(naive_glm, type = "response")), FALSE)
    naive_MSE <- format_stat(mean((input_Anywhere$n - predict(naive_glm, type = "response"))^2), FALSE)
    naive_rsquared <- format_stat(1 - (naive_summary$deviance / naive_summary$null.deviance), FALSE)
    naive_AIC <- format_stat(naive_summary$aic, FALSE)
    naive_z <- format_stat(coef(naive_summary)[2, 3], FALSE)
    naive_p <- format_stat(coef(naive_summary)[2, 4], FALSE)
    naive_meanIAS <- paste0(format_stat(mean(fitted(naive_glm)), FALSE), " (", format_stat(sd(fitted(naive_glm)), FALSE), ")")
    
    ## ------------------------------------------------------
    ## PLOTS OF MODELS - QUALITATIVE APPROACH (SURVEY EFFORT + NAIVE)
    ## ------------------------------------------------------ 
    
    p1 <- plot_qual_raw()
    
    p1.title <- p1 + patchwork::plot_annotation(title = paste0("Qualitative Model Plot: ",CountryName," (",x,")"))
    ggplot2::ggsave(filename = paste0(x,"_qualitative.png"), plot = p1.title, bg = "white", path = (paste0(workingDirectory, "/", subDirectory, "/", "Output/",x,"/Modelled IAS Rates/")), width = 6, height = 4, units = "in")
    
    
    ## ------------------------------------------------------
    ## DUMMY VARIBALES FOR MISSING MODELS
    ## ------------------------------------------------------ 
    create_dummy_variables(c("ConstDet", "SC", "Sampling"))
    
    
    ## ------------------------------------------------------
    ## ------------------------------------------------------
    ## ------------------------------------------------------
    # ----- modellingDecision = NO MODELLING -----
    ## ------------------------------------------------------
    ## ------------------------------------------------------
    ## ------------------------------------------------------
    
    
  } else {
    
    cli::cli_alert_warning("Model Decision = No modelling completed due to sparcity and/or incompleteness of data. No outputs produced.")
    
    ## ------------------------------------------------------
    ## DUMMY VARIBALES FOR ALL MODELS
    ## ------------------------------------------------------ 
    create_dummy_variables(c("naive", "ConstDet", "SC", "Sampling"))
    
  }
  
  ## COLLATED TABLE OF MODEL RESULTS 
  
  ## adds 4 lines to overall model output table for every country run in the loop 
  
  ## probably would benefit from adjusting this table output code so that a bunch of NA rows are not output for models that were not run in 
  ## different country outputs (depending on the modelling decision). This worked for me because I was looping through all countries, but having a cleaner
  ## table output based on the modelling decision would probably be better! 
  
  ## also just a note that currently the table output contains the text "did not run/converge" in the issues column of every model that was 
  ## either deliberately not run because of the modelling decision for a country, and also for all models that rna into a convergence issue etc. 
  ## and were therefore not included in the output. Ideally these two categories would output different text strings, but I just had some issues 
  ## getting it working and haven't fixed it yet, sorry! Figured it wouldn't matter too much for the pipeline anyway because this table will likely 
  ## end up being formatted very differently for the pipeline purposes! 

  
  naive_row <- tibble::tibble(p = tryCatch({coef(naive_summary)[2, 4]}, error = function(e) NA_real_),
                              prob_b1_zero = NA_real_,
                              b0_est = tryCatch({coef(naive_summary)[1, 1]}, error = function(e) NA_real_),
                              b1_est = tryCatch({coef(naive_summary)[2, 1]}, error = function(e) NA_real_),
                              gam0_est = NA_real_,
                              gam1_est = NA_real_,
                              gam2_est = NA_real_,
                              b0_se = tryCatch({coef(naive_summary)[1, 2]}, error = function(e) NA_real_),
                              b1_se = tryCatch({coef(naive_summary)[2, 2]}, error = function(e) NA_real_),
                              gam0_se = NA_real_,
                              gam1_se = NA_real_,
                              gam2_se = NA_real_,
                              aic = tryCatch({naive_summary$aic}, error = function(e) NA_real_),
                              bias = tryCatch({mean(input_Anywhere$n - predict(naive_glm, type = "response"))}, error = function(e) NA_real_),
                              mse = tryCatch({mean((input_Anywhere$n - predict(naive_glm, type = "response"))^2)}, error = function(e) NA_real_),
                              predictedIAS = tryCatch({mean(fitted(naive_glm))}, error = function(e) NA_real_),
                              predictedIAS_se = tryCatch({sd(fitted(naive_glm))/sqrt(length(fitted(naive_glm)))}, error = function(e) NA_real_),
                              rsquared = tryCatch({as.numeric(1 - (naive_summary$deviance / naive_summary$null.deviance))}, error = function(e) NA_real_),
                              issues = NA_character_) |>
    tibble::add_column(model = "naive", .before = "p")
  
  
  est_names <- c("b0_est", "b1_est", "gam0_est", "gam1_est", "gam2_est")
  ses_names <- c("b0_se", "b1_se", "gam0_se", "gam1_se", "gam2_se")
  
  snc_rows <- lapply(list(ConstDet, SC, Sampling), function(mod) {
    
    method <- dplyr::case_when(
      identical(mod, ConstDet) ~ "ConstDet",
      identical(mod, SC) ~ "SC",
      identical(mod, Sampling) ~ "Sampling"
    )
    
    model <- tryCatch(get(mod, envir = .GlobalEnv), error = function(e) NULL)
    warnings <- tryCatch(get(paste0(mod, "_warnings"), envir = .GlobalEnv), error = function(e) character(0))
    errors <- tryCatch(get(paste0(mod, "_error"), envir = .GlobalEnv), error = function(e) character(0))
    warn_flag <- length(warnings) > 0

    
    if (any(is.na(mod))){
      mod_row <- rep(NA,16) #number of parameters here
      names(mod_row) <- c("predictedIAS", "predictedIAS_se", "b0_est", "b1_est", "gam0_est", "gam1_est", "gam2_est", 
                          "b0_se", "b1_se", "gam0_se", "gam1_se", "gam2_se", 
                          "aic", "bias", "mse", "prob_b1_zero")
      mod_row <- dplyr::bind_rows(mod_row) |> 
        tibble::add_column(model = method, .before = "b0_est") |>
        tibble::add_column(rsquared = NA, .before = "prob_b1_zero") |>
        tibble::add_column(p = NA, .after = "rsquared") |>
        tibble::add_column(issues = paste0("did not run/converge"), .after = "p") 
      
    } else {
      
      par <- mod$coefficients$Estimate |> `names<-`(est_names[1:nrow(mod$coefficients)]) |> dplyr::bind_rows()
      ses <- mod$coefficients$`Std.Err` |> `names<-`(ses_names[1:nrow(mod$coefficients)])  |> dplyr::bind_rows()
      ## ALIEN R PACKAGE CODE outputs the minimised negative LL rather than the maximised LL - to calculate AIC, formula switches from - to + 
      ## AIC = 2 * k + 2 * (minimised Neg LL)
      aic <- tibble::tibble(aic = ((2 * nrow(mod$coefficients)) + (2 * mod$`log-likelihood`))) |> dplyr::bind_rows()
      bias <- tibble::tibble(bias = mean(mod$records - mod$fitted.values)) |> dplyr::bind_rows()
      mse <- tibble::tibble(mse = Metrics::mse(mod$records, mod$fitted.values)) |> dplyr::bind_rows() 
      predictedIAS <- tibble::tibble(predictedIAS = (mean(mod$fitted.values))) |> dplyr::bind_rows()
      predictedIAS_se <- tibble::tibble(predictedIAS_se = (sd(mod$fitted.values)/sqrt(length(mod$fitted.values)))) |> dplyr::bind_rows()
      prob_b1_zero <- tibble::tibble(prob_b1_zero = alien::summary_snc(mod)[2, 3]) |> dplyr::bind_rows()
      mod_row <- dplyr::bind_cols(prob_b1_zero, par, ses, aic, bias, mse, predictedIAS, predictedIAS_se) |> 
        tibble::add_column(model = method, .before = "prob_b1_zero") |>
        tibble::add_column(rsquared = NA) |>
        tibble::add_column(p = NA) |>
        tibble::add_column(issues = NA_character_)
    }
  }
  )
  
  params <- dplyr::bind_rows(naive_row, snc_rows) |>
    tibble::add_column(firstRecordCompleteness = firstRecordCompleteness, .before = "model") |>
    tibble::add_column(nonZeroYears = nonZeroYears, .before = "firstRecordCompleteness") |>
    tibble::add_column(modellingDecision = decision, .before = "nonZeroYears") |>
    tibble::add_column(interpretWithCaution = interpretationFlag, .before = "modellingDecision") |>
    tibble::add_column(country = CountryName, .before = "interpretWithCaution") |>
    tibble::add_column(ISO = x, .before = "country") |> 
    tibble::add_column(notes = case_when(isTRUE(interpretationFlag) ~ "interpret result with caution", 
                                         TRUE ~ ""), .after = "issues")
  
  datalist[[i]] <- params # add it to list
  
  
}

out <- dplyr::bind_rows(datalist)



