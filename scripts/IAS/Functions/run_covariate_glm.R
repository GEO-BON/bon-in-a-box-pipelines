## ----------------------------------------------------------------------------------
## FUNCTION TO RUN SURVEY EFFORT GLM WITH DIFFERENT DISTRIBUTION DEPENDING ON RESULTS
## ----------------------------------------------------------------------------------

run_covariate_glm <- function() {
  
  model_status <- NULL
  covariate_glm <- NULL
  dispersion <- NULL
  
  try1 <- tryCatch(MASS::glm.nb(recordscount ~ time, data = input_Anywhere), error = function(e) error_occurred <<- TRUE, warning = function(w) warning_occurred <<- TRUE)
  
  if(!isTRUE(try1)) {
    covariate_glm <- MASS::glm.nb(recordscount ~ time, data = input_Anywhere)
    simulationOutput <- DHARMa::simulateResiduals(fittedModel = covariate_glm)
    dispersion <- suppressWarnings(DHARMa::testDispersion(simulationOutput)$statistic)
  }
  
  if (dispersion < 0.8 || dispersion > 1.2 || isTRUE(try1)) {
    
    model_status <- "quasipoisson"
    covariate_glm <- glm(recordscount ~ time, data = input_Anywhere, family = "quasipoisson")
    dispersion <- summary(covariate_glm)$dispersion
  
    } else {
    
      model_status <- "NegBin"
      title <- paste0(x, " - Neg Bin: dispersion = ", round(dispersion, 2))
      png(filename = paste0(workingDirectory, "/", subDirectory, "/", "Output/",x,"/Modelled IAS Rates/",x,"_survey_effort_diagnostics.png"), bg = "white", width = 6, height = 6, units = "in", res = 200)
      suppressMessages(suppressWarnings(plot(simulationOutput, title = title)))
      dev.off()
    }
  
  assign(paste0("covariate_glm"), covariate_glm, envir = .GlobalEnv)
  assign(paste0("covariate_distribution"), model_status, envir = .GlobalEnv)
  assign(paste0("covariate_dispersion"), dispersion, envir = .GlobalEnv)
  
  library(MASS)
    
  if (model_status == "NegBin") {

    p <- ggplot(input_Anywhere, aes(x=time, y=recordscount)) +
      geom_smooth(aes(linetype = factor("smoothed", levels = c("smoothed", "raw"))), method = "glm.nb", se = FALSE, colour = "#863c1d", alpha = 0.4, linewidth = 0.7, show.legend = TRUE, formula = y ~ x) +
      geom_line(aes(linetype = factor("raw", levels = c("smoothed", "raw"))), linewidth = 0.7) +
      scale_x_continuous(expand = c(0, 0), limits = c(0, 51), breaks = c(0.01, 10, 20, 30, 40, 50), labels = c("1970", "1980", "1990", "2000", "2010", "2020")) +
      scale_y_continuous(expand = c(0, 0), limits = c(0, NA), breaks = scales::breaks_pretty(n = 5), labels = label_number(scale = 1/1e6, suffix = "M")) +
      scale_linetype_manual(name = NULL,
                            values = c("smoothed" = "solid", "raw" = "dashed"),
                            labels = c("Survey Effort Proxy", "New GBIF Records")) +
      labs(x = "Year", y = "New GBIF Records", linetype="Legend") +
      theme_classic() +
      theme(legend.position = "inside",
            legend.position.inside = c(0.05, .95),
            legend.justification = c("left", "top"),
            legend.key = element_rect(fill = NA))

    return(p)
    ggplot2::ggsave(filename = paste0(x,"_survey_effort.png"), plot = p, bg = "white", path = paste0(workingDirectory, "/", subDirectory, "/", "Output/",x,"/Modelled IAS Rates/"), width = 5.5, height = 3, units = "in")

  } else if (model_status == "quasipoisson") {

      p <- ggplot(input_Anywhere, aes(x=time, y=recordscount)) +
        geom_smooth(aes(linetype = factor("smoothed", levels = c("smoothed", "raw"))), method = "glm", method.args = list(family= quasipoisson), se = FALSE, colour = "#863c1d", alpha = 0.4, linewidth = 0.7, show.legend = TRUE, formula = y ~ x) +
        geom_line(aes(linetype = factor("raw", levels = c("smoothed", "raw"))), linewidth = 0.7) +
        scale_x_continuous(expand = c(0, 0), limits = c(0, 51), breaks = c(0.01, 10, 20, 30, 40, 50), labels = c("1970", "1980", "1990", "2000", "2010", "2020")) +
        scale_y_continuous(expand = c(0, 0), limits = c(0, NA), breaks = scales::breaks_pretty(n = 5), labels = label_number(scale = 1/1e6, suffix = "M")) +
        scale_linetype_manual(name = NULL,
                              values = c("smoothed" = "solid", "raw" = "dashed"),
                              labels = c("Survey Effort Proxy", "New GBIF Records")) +
        labs(x = "Year", y = "New GBIF Records", linetype="Legend") +
        theme_classic() +
        theme(legend.position = "inside",
              legend.position.inside = c(0.05, .95),
              legend.justification = c("left", "top"),
              legend.key = element_rect(fill = NA))

      return(p)
      ggplot2::ggsave(filename = paste0(x,"_survey_effort.png"), plot = p, bg = "white", path = paste0(workingDirectory, "/", subDirectory, "/", "Output/",x,"/Modelled IAS Rates/"), width = 5.5, height = 3, units = "in")

  }

}
