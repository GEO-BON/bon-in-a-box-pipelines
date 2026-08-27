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

## NOTE: The original script was run from P6_runWorkflow.R. The BON in a Box
## adaptation below replaces only the desktop input/output setup.

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(tidyr)
})

input <- biab_inputs()

read_input_table <- function(path, label) {
  if (is.null(path) || length(path) != 1 || !file.exists(path)) {
    biab_error_stop(paste0(label, " input does not exist: ", path))
  }

  separator <- if (grepl("\\.tsv$", path, ignore.case = TRUE)) "\t" else ","
  data <- read.table(
    path,
    header = TRUE,
    sep = separator,
    quote = "\"",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  if (ncol(data) == 1 && separator == ",") {
    data <- read.table(
      path,
      header = TRUE,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  }

  data
}

required_columns <- function(data, columns, label) {
  missing_columns <- setdiff(columns, colnames(data))
  if (length(missing_columns) > 0) {
    biab_error_stop(paste(
      label, "is missing required column(s):",
      paste(missing_columns, collapse = ", ")
    ))
  }
}

interpretation_scope <- paste(
  "Results cover 1970-2020 and use GRIIS checklist taxa flagged invasive",
  "anywhere that have a standardised first-record year. A first record is",
  "the first documented detection, not necessarily the true introduction or",
  "establishment year."
)

interpretation_references <- paste(
  "McGeoch et al. (2023), doi:10.1111/conl.12981;",
  "Buba et al. (2024), doi:10.1111/geb.13859;",
  "SInAS 3.1.1, doi:10.5281/zenodo.18220953"
)

model_guidance <- tibble::tribble(
  ~model, ~modelDescription, ~modelAssumption, ~interpretationCaveat,
  "naive",
  "Poisson trend fitted directly to annual IAS first-record counts.",
  "Introductions are detected without delay and detection is effectively perfect.",
  paste(
    "The trend can reflect changing observation effort or detection delay,",
    "not introductions alone."
  ),
  "ConstDet",
  "Introduction-rate model with a constant probability of detecting introduced species.",
  "Detection probability remains constant through time.",
  "The trend can be biased when survey effort or detectability changes through time.",
  "SC",
  "Solow and Costello model estimating introduction and time-varying detection processes.",
  "Detection changes through time and with post-introduction population growth.",
  paste(
    "The additional detection and growth parameters require a long,",
    "information-rich first-record series and may be unstable with sparse data."
  ),
  "Sampling",
  "Introduction-rate model using annual GBIF records as an external sampling-effort proxy.",
  "GBIF record volume tracks the observation effort affecting IAS discovery.",
  paste(
    "GBIF records are an indirect proxy, not direct IAS survey effort; inference",
    "depends on how well the proxy represents the process that produced first records."
  )
)

interpret_model_result <- function(model, status, b1) {
  if (is.na(status) || status != "fitted") {
    return("No fitted result is available to interpret; see status and issues.")
  }
  if (is.na(b1)) {
    return("The model fitted, but its time-trend coefficient is unavailable.")
  }

  direction <- if (b1 > 0) {
    "increased"
  } else if (b1 < 0) {
    "decreased"
  } else {
    "showed no estimated change"
  }
  response <- if (model == "naive") {
    "observed annual first-record rate"
  } else {
    "model-estimated annual introduction rate"
  }
  paste0(
    "The ", response, " ", direction,
    " over 1970-2020 (b1 = ", format(signif(b1, 4), trim = TRUE),
    "). Interpret the direction together with uncertainty, model fit, convergence, ",
    "and the stated detection assumption."
  )
}

select_modelling_decision <- function(nonZeroYears, firstRecordCompleteness) {
  modellingDecision <- if (
    nonZeroYears >= 25 && firstRecordCompleteness >= 25
  ) {
    "model all"
  } else if (
    nonZeroYears >= 15 && nonZeroYears < 25 &&
      firstRecordCompleteness >= 25
  ) {
    "model subset"
  } else if (
    nonZeroYears >= 15 && firstRecordCompleteness < 25
  ) {
    "qualitative"
  } else if (
    nonZeroYears >= 10 && nonZeroYears < 15 &&
      firstRecordCompleteness >= 25
  ) {
    "qualitative"
  } else {
    "nothing"
  }

  modellingDecision_Formatted <- switch(
    modellingDecision,
    "model all" = "Model all model options",
    "model subset" = "Model subset of models (excluding S&C)",
    "qualitative" = "Qualitative approach",
    "Too data sparse to model IAS rate"
  )

  decisionReason <- switch(
    modellingDecision,
    "model all" = paste(
      "At least 25 years contain first records and first-record",
      "completeness is at least 25%."
    ),
    "model subset" = paste(
      "Between 15 and 24 years contain first records and first-record",
      "completeness is at least 25%; the S&C growth model is excluded."
    ),
    "qualitative" = if (firstRecordCompleteness < 25) {
      paste(
        "At least 15 years contain first records, but first-record",
        "completeness is below 25%; only the qualitative approach is used."
      )
    } else {
      paste(
        "Between 10 and 14 years contain first records and first-record",
        "completeness is at least 25%; only the qualitative approach is used."
      )
    },
    paste(
      "The data do not meet the minimum combination of 10 non-zero years",
      "and 25% first-record completeness required for modelling."
    )
  )

  interpretationFlag <- (
    nonZeroYears >= 15 &&
      firstRecordCompleteness >= 25 &&
      firstRecordCompleteness < 50
  )

  list(
    decision = modellingDecision,
    formatted = modellingDecision_Formatted,
    reason = decisionReason,
    interpretWithCaution = interpretationFlag
  )
}

ensure_alien_package <- function() {
  if (!requireNamespace("alien", quietly = TRUE)) {
    cli::cli_alert_info(
      "Installing the CRAN alien package required by the selected quantitative models."
    )
    remotes::install_version(
      "alien",
      version = "1.0.2",
      repos = "https://cloud.r-project.org",
      dependencies = NA,
      upgrade = "never",
      quiet = TRUE
    )
  }

  if (!requireNamespace("alien", quietly = TRUE)) {
    biab_error_stop(
      "The CRAN alien package could not be installed, so quantitative models cannot run."
    )
  }
}

function_file <- function(filename) {
  candidates <- c(
    file.path("/scripts/IAS/Functions", filename),
    file.path("scripts/IAS/Functions", filename),
    file.path("Functions", filename)
  )
  existing <- candidates[file.exists(candidates)]
  if (length(existing) == 0) {
    biab_error_stop(paste("Required modeling function was not found:", filename))
  }
  existing[[1]]
}

country <- input$country_name$country
Countries <- country$ISO3
CountryNames <- country$englishName

if (length(Countries) != 1 || is.null(Countries) || is.na(Countries)) {
  biab_error_stop("Select exactly one country before running this step.")
}

IntegratedDataInput <- read_input_table(input$integrated_data, "Integrated IAS data")
CovariateDataInput <- read_input_table(input$covariate_data, "GBIF covariate data")

required_columns(
  IntegratedDataInput,
  c("origDB", "eventDate", "kingdom"),
  "Integrated IAS data"
)

if (!"isInvasiveAnywhere" %in% colnames(IntegratedDataInput)) {
  if ("isInvasiveInCountry" %in% colnames(IntegratedDataInput)) {
    IntegratedDataInput$isInvasiveAnywhere <-
      IntegratedDataInput$isInvasiveInCountry
  } else {
    biab_error_stop(paste(
      "Integrated IAS data must contain either isInvasiveAnywhere",
      "or isInvasiveInCountry."
    ))
  }
}

if (!"linkID" %in% colnames(IntegratedDataInput)) {
  IntegratedDataInput$linkID <- ifelse(
    grepl("GRIIS", IntegratedDataInput$origDB, ignore.case = TRUE),
    "G",
    "F"
  )
}

IntegratedDataInput$eventDate <- suppressWarnings(
  as.integer(IntegratedDataInput$eventDate)
)
IntegratedDataInput$kingdom <- tools::toTitleCase(
  tolower(as.character(IntegratedDataInput$kingdom))
)
IntegratedDataInput$isInvasiveAnywhere <- toupper(
  as.character(IntegratedDataInput$isInvasiveAnywhere)
)

required_columns(CovariateDataInput, "year", "GBIF covariate data")
CovariateDataInput$year <- suppressWarnings(
  as.integer(CovariateDataInput$year)
)

covariate_count_column <- intersect(
  c("recordscount", "RecordsCount", "gbifRecordsCount", "count"),
  colnames(CovariateDataInput)
)

if (length(covariate_count_column) == 0) {
  CovariateDataInput <- CovariateDataInput %>%
    dplyr::filter(!is.na(year)) %>%
    dplyr::count(year, name = "recordscount")
} else {
  covariate_count_column <- covariate_count_column[[1]]
  CovariateDataInput <- CovariateDataInput %>%
    dplyr::transmute(
      year = year,
      recordscount = suppressWarnings(
        as.numeric(.data[[covariate_count_column]])
      )
    ) %>%
    dplyr::filter(!is.na(year)) %>%
    dplyr::group_by(year) %>%
    dplyr::summarise(
      recordscount = sum(recordscount, na.rm = TRUE),
      .groups = "drop"
    )
}

# Pre-create lists for the original country loop and BON outputs.
datalist <- vector("list", length = length(Countries))
decisionlist <- vector("list", length = length(Countries))
summarylist <- vector("list", length = length(Countries))
inputlist <- vector("list", length = length(Countries))

## ------------------------------------------------------
## ADD REQUIRED FUNCTIONS TO GLOBAL ENVIRONMENT
## ------------------------------------------------------

source(function_file("plot_comp_all.R"))
source(function_file("plot_qual_raw.R"))
source(function_file("create_dummy_variables.R"))
source(function_file("check_convergence.R"))
source(function_file("format_stat.R"))
source(function_file("run_covariate_glm.R"))
source(function_file("fit_snc_model.R"))
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
  CountryName <- CountryNames[[i]]
  CountryCode <- x
  
  ## ------------------------------------------------------
  ## LOAD REQUIRED DATA
  ## ------------------------------------------------------ 
  
  # Copy and load .csv integrated IAS data file from P5
  IntegratedData <- IntegratedDataInput
  
  # Copy and load .rds covariate data file from P5 - SQL method file 
  CovariateData <- CovariateDataInput
  
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
  
  firstRecordCompleteness <- if (nrow(allIAS) == 0) {
    0
  } else {
    (nrow(IASWithFirstRecords) / nrow(allIAS)) * 100
  }
  
  ## CRITERIA 2 - NON-ZERO YEARS
  
  nonZeroYears <- input_Anywhere %>%
    filter(n != 0) %>%
    nrow()
  
  ## Modelling decision framework for combinations of criteria 1 and criteria 2 
  
  decisionCriteria <- data.frame(
    ModellingDecisions = c("NonZeroYears_<10", "NonZeroYears_10to15", "NonZeroYears_15to25", "NonZeroYears_>25"), 
    firstRecordComp_50to100pcnt = c("Too data sparse to model IAS rate", "Qualitative approach", "Model subset of models (excluding S&C)", "Model all model options"), 
    firstRecordComp_25to50pcnt = c("Too data sparse to model IAS rate", "Qualitative approach", "Model subset of models (excluding S&C), but interpret with caution", "Model all model options, but interpret with caution"), 
    firstRecordComp_0to25pcnt = c("Too data sparse to model IAS rate", "Too data sparse to model IAS rate", "Qualitative approach", "Qualitative approach")
  )

  # Apply the original thresholds and record why BON selected this branch.
  decision_result <- select_modelling_decision(
    nonZeroYears,
    firstRecordCompleteness
  )
  modellingDecision <- decision_result$decision
  modellingDecision_Formatted <- decision_result$formatted
  decisionReason <- decision_result$reason
  interpretationFlag <- decision_result$interpretWithCaution
  
  if (interpretationFlag == TRUE) {
    cli::cli_alert_warning("A large number of species in the country checklist do not have a date 
                           of establishment (First Record). This may impact the quality of the 
                           data modelling, and therefore results must be interpreted with caution.")
  }
  
  decision <- modellingDecision
  
  
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
  
  summarylist[[i]] <- summary %>%
    dplyr::rename(value = dplyr::all_of(x)) %>%
    dplyr::mutate(country = CountryName, ISO = x, .before = 1)

  decisionlist[[i]] <- tibble::tibble(
    ISO = x,
    country = CountryName,
    firstRecordCompleteness = round(firstRecordCompleteness, 2),
    nonZeroYears = nonZeroYears,
    modellingDecision = modellingDecision,
    modellingDecisionFormatted = modellingDecision_Formatted,
    decisionReason = decisionReason,
    interpretWithCaution = interpretationFlag,
    interpretationLevel = dplyr::case_when(
      modellingDecision %in% c("model all", "model subset") ~
        "quantitative model comparison",
      modellingDecision == "qualitative" ~ "descriptive comparison only",
      TRUE ~ "no introduction-rate inference"
    ),
    interpretationGuidance = dplyr::case_when(
      modellingDecision %in% c("model all", "model subset") ~ paste(
        "Interpret only fitted, converged models. Compare AIC only among models",
        "fitted to this same country and time series; lower AIC indicates stronger",
        "relative support, not that model assumptions are true."
      ),
      modellingDecision == "qualitative" ~ paste(
        "Compare first-record and GBIF-record patterns descriptively. This branch",
        "does not provide a survey-effort-corrected introduction-rate estimate."
      ),
      TRUE ~ paste(
        "The available first-record series is too sparse or incomplete for a",
        "defensible introduction-rate interpretation."
      )
    ),
    interpretationScope = interpretation_scope,
    references = interpretation_references,
    modelsSelected = dplyr::case_when(
      modellingDecision == "model all" ~
        "naive; ConstDet; SC; Sampling",
      modellingDecision == "model subset" ~
        "naive; ConstDet; Sampling",
      modellingDecision == "qualitative" ~
        "naive (with survey-effort comparison)",
      TRUE ~ "none"
    )
  )

  inputlist[[i]] <- input_Anywhere %>%
    dplyr::mutate(country = CountryName, ISO = x, .before = 1)
  
  
  
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

    ensure_alien_package()
    
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
    
    ## ------------------------------------------------------
    ## PLOTS OF MODELS - QUALITATIVE APPROACH (SURVEY EFFORT + NAIVE)
    ## ------------------------------------------------------ 
    
    p1 <- plot_qual_raw()
    
    qualitative_result <- get_qualitative_interpretation()
    p1.title <- add_qualitative_title(p1, CountryName, x)
    qualitative_plot_path <- file.path(
      outputFolder,
      paste0(x, "_qualitative.png")
    )
    ggplot2::ggsave(
      filename = qualitative_plot_path,
      plot = p1.title,
      bg = "white",
      width = 6,
      height = 4,
      units = "in"
    )
    
    ## ------------------------------------------------------
    ## PLOTS OF MODELS - COMPARATIVE APPROACH (NAIVE + S&C + SAMPLING + CONSTANT DETECTION)
    ## ------------------------------------------------------ 
    
    p2 <- plot_comp_all()
    
    p2.title <- p2 + ggplot2::labs(
      title = paste0("First-record model comparison: ", CountryName, " (", x, ")"),
      subtitle = "Fitted annual discovery records under alternative detection assumptions.",
      caption = "Compare AIC only among fitted models for this same country and time series."
    )
    quantitative_plot_path <- file.path(
      outputFolder,
      paste0(x, "_quantitative.png")
    )
    ggplot2::ggsave(
      filename = quantitative_plot_path,
      plot = p2.title,
      bg = "white",
      width = 6,
      height = 4,
      units = "in"
    )
  
   
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

    ensure_alien_package()
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
    
    ## ------------------------------------------------------
    ## PLOTS OF MODELS - QUALITATIVE APPROACH (SURVEY EFFORT + NAIVE)
    ## ------------------------------------------------------ 
    
    p1 <- plot_qual_raw()
    
    qualitative_result <- get_qualitative_interpretation()
    p1.title <- add_qualitative_title(p1, CountryName, x)
    qualitative_plot_path <- file.path(
      outputFolder,
      paste0(x, "_qualitative.png")
    )
    ggplot2::ggsave(
      filename = qualitative_plot_path,
      plot = p1.title,
      bg = "white",
      width = 6,
      height = 4,
      units = "in"
    )
    
    ## ------------------------------------------------------
    ## PLOTS OF MODELS - COMPARATIVE APPROACH (NAIVE + SAMPLING + CONSTANT DETECTION)
    ## ------------------------------------------------------ 
    
    p2 <- plot_comp_all()
    
    p2.title <- p2 + ggplot2::labs(
      title = paste0("First-record model comparison: ", CountryName, " (", x, ")"),
      subtitle = "Fitted annual discovery records under alternative detection assumptions.",
      caption = "Compare AIC only among fitted models for this same country and time series."
    )
    quantitative_plot_path <- file.path(
      outputFolder,
      paste0(x, "_quantitative.png")
    )
    ggplot2::ggsave(
      filename = quantitative_plot_path,
      plot = p2.title,
      bg = "white",
      width = 6,
      height = 4,
      units = "in"
    )
    
    
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
    
    qualitative_result <- get_qualitative_interpretation()
    p1.title <- add_qualitative_title(p1, CountryName, x)
    qualitative_plot_path <- file.path(
      outputFolder,
      paste0(x, "_qualitative.png")
    )
    ggplot2::ggsave(
      filename = qualitative_plot_path,
      plot = p1.title,
      bg = "white",
      width = 6,
      height = 4,
      units = "in"
    )
    
    
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
    
    cli::cli_alert_warning(
      "Model Decision = No modelling completed due to sparsity and/or incompleteness of data. Decision and data-summary outputs will still be produced."
    )
    
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

  
  empty_model_row <- function(method, status, issues) {
    tibble::tibble(
      model = method,
      p = NA_real_,
      prob_b1_zero = NA_real_,
      b0_est = NA_real_,
      b1_est = NA_real_,
      gam0_est = NA_real_,
      gam1_est = NA_real_,
      gam2_est = NA_real_,
      b0_se = NA_real_,
      b1_se = NA_real_,
      gam0_se = NA_real_,
      gam1_se = NA_real_,
      gam2_se = NA_real_,
      aic = NA_real_,
      bias = NA_real_,
      mse = NA_real_,
      predictedIAS = NA_real_,
      predictedIAS_se = NA_real_,
      rsquared = NA_real_,
      status = status,
      issues = issues
    )
  }

  models_selected <- switch(
    decision,
    "model all" = c("naive", "ConstDet", "SC", "Sampling"),
    "model subset" = c("naive", "ConstDet", "Sampling"),
    "qualitative" = "naive",
    character(0)
  )

  naive_fitted <- (
    exists("naive_glm", inherits = FALSE) &&
      inherits(naive_glm, "glm")
  )

  if (naive_fitted) {
    naive_row <- tibble::tibble(
      model = "naive",
      p = tryCatch(coef(naive_summary)[2, 4], error = function(e) NA_real_),
      prob_b1_zero = NA_real_,
      b0_est = tryCatch(coef(naive_summary)[1, 1], error = function(e) NA_real_),
      b1_est = tryCatch(coef(naive_summary)[2, 1], error = function(e) NA_real_),
      gam0_est = NA_real_,
      gam1_est = NA_real_,
      gam2_est = NA_real_,
      b0_se = tryCatch(coef(naive_summary)[1, 2], error = function(e) NA_real_),
      b1_se = tryCatch(coef(naive_summary)[2, 2], error = function(e) NA_real_),
      gam0_se = NA_real_,
      gam1_se = NA_real_,
      gam2_se = NA_real_,
      aic = tryCatch(naive_summary$aic, error = function(e) NA_real_),
      bias = tryCatch(
        mean(input_Anywhere$n - predict(naive_glm, type = "response")),
        error = function(e) NA_real_
      ),
      mse = tryCatch(
        mean((input_Anywhere$n - predict(naive_glm, type = "response"))^2),
        error = function(e) NA_real_
      ),
      predictedIAS = tryCatch(
        mean(fitted(naive_glm)),
        error = function(e) NA_real_
      ),
      predictedIAS_se = tryCatch(
        sd(fitted(naive_glm)) / sqrt(length(fitted(naive_glm))),
        error = function(e) NA_real_
      ),
      rsquared = tryCatch(
        as.numeric(1 - (naive_summary$deviance / naive_summary$null.deviance)),
        error = function(e) NA_real_
      ),
      status = "fitted",
      issues = NA_character_
    )
  } else {
    naive_row <- empty_model_row(
      "naive",
      "not selected",
      "Not run under the selected modelling decision."
    )
  }

  est_names <- c("b0_est", "b1_est", "gam0_est", "gam1_est", "gam2_est")
  ses_names <- c("b0_se", "b1_se", "gam0_se", "gam1_se", "gam2_se")

  snc_rows <- lapply(c("ConstDet", "SC", "Sampling"), function(method) {
    mod <- get0(method, envir = .GlobalEnv, ifnotfound = NA)
    warnings <- get0(
      paste0(method, "_warnings"),
      envir = .GlobalEnv,
      ifnotfound = character(0)
    )
    errors <- get0(
      paste0(method, "_error"),
      envir = .GlobalEnv,
      ifnotfound = character(0)
    )
    warnings <- as.character(warnings[!is.na(warnings) & nzchar(warnings)])
    errors <- as.character(errors[!is.na(errors) & nzchar(errors)])

    valid_model <- is.list(mod) && !is.null(mod$coefficients)
    selected <- method %in% models_selected

    if (!valid_model) {
      issue_text <- if (!selected) {
        "Not run under the selected modelling decision."
      } else if (length(errors) > 0) {
        paste(unique(errors), collapse = "; ")
      } else {
        "Selected model did not run or converge."
      }
      return(empty_model_row(
        method,
        if (selected) "failed" else "not selected",
        issue_text
      ))
    }

    estimates <- stats::setNames(rep(NA_real_, length(est_names)), est_names)
    standard_errors <- stats::setNames(
      rep(NA_real_, length(ses_names)),
      ses_names
    )
    parameter_count <- min(nrow(mod$coefficients), length(est_names))
    estimates[seq_len(parameter_count)] <-
      as.numeric(mod$coefficients$Estimate[seq_len(parameter_count)])
    standard_errors[seq_len(parameter_count)] <-
      as.numeric(mod$coefficients$`Std.Err`[seq_len(parameter_count)])

    fitted_values <- mod$fitted.values
    if (is.null(fitted_values) && !is.null(mod$predict$mean)) {
      fitted_values <- mod$predict$mean
    }

    issues <- unique(c(warnings, errors))
    issues <- if (length(issues) == 0) {
      NA_character_
    } else {
      paste(issues, collapse = "; ")
    }

    tibble::tibble(
      model = method,
      p = NA_real_,
      prob_b1_zero = tryCatch(
        as.numeric(alien::summary_snc(mod)[2, 3]),
        error = function(e) NA_real_
      ),
      !!!as.list(estimates),
      !!!as.list(standard_errors),
      # alien outputs minimized negative log-likelihood, so AIC uses + 2LL.
      aic = (2 * nrow(mod$coefficients)) + (2 * mod$`log-likelihood`),
      bias = mean(mod$records - fitted_values),
      mse = Metrics::mse(mod$records, fitted_values),
      predictedIAS = mean(fitted_values),
      predictedIAS_se = sd(fitted_values) / sqrt(length(fitted_values)),
      rsquared = NA_real_,
      status = "fitted",
      issues = issues
    )
  })
  
  params <- dplyr::bind_rows(naive_row, snc_rows) |>
    tibble::add_column(firstRecordCompleteness = firstRecordCompleteness, .before = "model") |>
    tibble::add_column(nonZeroYears = nonZeroYears, .before = "firstRecordCompleteness") |>
    tibble::add_column(modellingDecision = decision, .before = "nonZeroYears") |>
    tibble::add_column(interpretWithCaution = interpretationFlag, .before = "modellingDecision") |>
    tibble::add_column(country = CountryName, .before = "interpretWithCaution") |>
    tibble::add_column(ISO = x, .before = "country") |>
    dplyr::left_join(model_guidance, by = "model") |>
    dplyr::mutate(
      trendDirection = dplyr::case_when(
        status != "fitted" | is.na(b1_est) ~ "not available",
        b1_est > 0 ~ "increasing",
        b1_est < 0 ~ "decreasing",
        TRUE ~ "no estimated change"
      ),
      resultInterpretation = mapply(
        interpret_model_result, model, status, b1_est,
        USE.NAMES = FALSE
      ),
      interpretationScope = interpretation_scope,
      references = interpretation_references
    ) |>
    tibble::add_column(
      notes = dplyr::case_when(
        isTRUE(interpretationFlag) ~ paste(
          "First-record completeness is below 50%; interpret quantitative",
          "estimates with additional caution."
        ),
        TRUE ~ ""
      ),
      .after = "issues"
    )
  
  datalist[[i]] <- params # add it to list
  
  
}

out <- dplyr::bind_rows(datalist)
model_decision <- dplyr::bind_rows(decisionlist)
data_summary <- dplyr::bind_rows(summarylist)
model_input <- dplyr::bind_rows(inputlist)

if (exists("qualitative_result")) {
  model_decision <- model_decision %>%
    dplyr::mutate(
      qualitativeIASTrend = qualitative_result$ias_trend,
      qualitativeSurveyEffortTrend = qualitative_result$survey_trend,
      qualitativeInterpretation = qualitative_result$interpretation
    )
}

model_outputs_path <- file.path(outputFolder, "model_outputs.csv")
model_decision_path <- file.path(outputFolder, "model_decision.csv")
data_summary_path <- file.path(outputFolder, "data_summary.csv")
model_input_path <- file.path(outputFolder, "model_input.csv")

write.csv(out, model_outputs_path, row.names = FALSE, na = "")
write.csv(model_decision, model_decision_path, row.names = FALSE, na = "")
write.csv(data_summary, data_summary_path, row.names = FALSE, na = "")
write.csv(model_input, model_input_path, row.names = FALSE, na = "")

biab_output("model_outputs", model_outputs_path)
biab_output("model_decision", model_decision_path)
biab_output("data_summary", data_summary_path)
biab_output("model_input", model_input_path)

if (exists("qualitative_plot_path") && file.exists(qualitative_plot_path)) {
  biab_output("qualitative_plot", qualitative_plot_path)
} else {
  biab_output("qualitative_plot", NULL)
}
if (exists("qualitative_result")) {
  biab_output(
    "qualitative_interpretation",
    paste0(
      qualitative_result$interpretation,
      " (IAS observations: ", tolower(qualitative_result$ias_trend),
      "; survey effort: ", tolower(qualitative_result$survey_trend), ")."
    )
  )
} else {
  biab_output("qualitative_interpretation", NULL)
}
if (exists("quantitative_plot_path") && file.exists(quantitative_plot_path)) {
  biab_output("quantitative_plot", quantitative_plot_path)
} else {
  biab_output("quantitative_plot", NULL)
}
