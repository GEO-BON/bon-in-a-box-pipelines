
## ------------------------------------------------------
## PLOTS OF MODELS - MERGED - QUALITATIVE APPROACH (p1 + p2) WITH RAW DATA POINTS
## ------------------------------------------------------ 

classify_qualitative_slope <- function(model, alpha = 0.05) {
  coefficient_table <- summary(model)$coefficients
  if (!"time" %in% rownames(coefficient_table)) {
    stop("Qualitative trend model does not contain a time coefficient.")
  }

  estimate <- unname(coefficient_table["time", 1])
  p_value <- unname(coefficient_table["time", ncol(coefficient_table)])

  if (!is.finite(estimate) || !is.finite(p_value) || p_value >= alpha) {
    return("Stable")
  }
  if (estimate < 0) "Decreasing" else "Increasing"
}

qualitative_interpretation <- function(ias_trend, survey_trend) {
  interpretations <- c(
    "Decreasing|Decreasing" =
      "Increasing risk of underestimating new IAS introductions",
    "Decreasing|Stable" =
      "Adequacy of survey effort unknown and therefore invasion trend unknown",
    "Decreasing|Increasing" = paste(
      "Evidence for and increasing certainty in successful",
      "prevention/management"
    ),
    "Stable|Decreasing" =
      "Increasing risk of underestimating new IAS introductions",
    "Stable|Stable" = paste(
      "Interpretation dependent on level and relative level of survey effort",
      "and IAS introductions"
    ),
    "Stable|Increasing" = "Increasing certainty in invasion trends",
    "Increasing|Decreasing" = paste(
      "Compound risk of underestimating new IAS introductions"
    ),
    "Increasing|Stable" =
      "High risk of underestimating new IAS introductions",
    "Increasing|Increasing" = paste(
      "Maintain survey effort and increase prevention efforts to reduce",
      "IAS introductions"
    )
  )

  key <- paste(ias_trend, survey_trend, sep = "|")
  unname(interpretations[[key]])
}

get_qualitative_interpretation <- function() {
  ias_trend <- classify_qualitative_slope(naive_glm)
  survey_trend <- classify_qualitative_slope(covariate_glm)
  list(
    ias_trend = ias_trend,
    survey_trend = survey_trend,
    interpretation = qualitative_interpretation(ias_trend, survey_trend)
  )
}

add_qualitative_title <- function(plot, country_name, iso3) {
  plot + ggplot2::labs(
    title = paste0(
      "First records and GBIF observation proxy: ", country_name,
      " (", iso3, ")"
    ),
    subtitle = NULL,
    caption = NULL
  )
}

plot_qual_raw <- function() {
  
  #library(MASS)
  library(ggeffects)
  
  cov.predictions <- as.data.frame(ggeffects::predict_response(covariate_glm, terms = "time [0:51]", ci_level = 0.95), terms_to_colnames = TRUE)
  cov.predictions <- cov.predictions %>% rename_with(~ paste0("COV.", .), -time)
  cov.predictions <- cov.predictions[, -ncol(cov.predictions)]
  naive.predictions <- as.data.frame(ggeffects::predict_response(naive_glm, terms = "time [0:51]", ci_level = 0.95), terms_to_colnames = TRUE)
  naive.predictions <- naive.predictions %>% rename_with(~ paste0("NAIVE.", .), -time)
  naive.predictions <- naive.predictions[, -ncol(naive.predictions)]
  preds <- full_join(naive.predictions, cov.predictions)
  
  max_covariate <- max(input_Anywhere$recordscount, na.rm = TRUE)
  scaleFactor <- if (is.finite(max_covariate) && max_covariate > 0) {
    max(input_Anywhere$n, na.rm = TRUE) / max_covariate
  } else {
    1
  }
  
  p <- ggplot() +
    geom_point(data = input_Anywhere, aes(x = time, y=n, colour = "IAS First Records", fill = "IAS First Records")) +
    geom_line(data = preds, aes(y=NAIVE.predicted, x = time, colour = "Naive Model")) +
    geom_ribbon(data = preds, aes(x = time, ymin=NAIVE.conf.low, ymax = NAIVE.conf.high, fill = "Naive Model"), alpha = 0.4) +
    geom_point(data = input_Anywhere, aes(x = time, y=recordscount * scaleFactor, colour = "GBIF Records", fill = "GBIF Records")) +
    geom_line(data = preds, aes(x = time, y=(COV.predicted*scaleFactor), colour = "Survey Effort Proxy")) +
    geom_ribbon(data = preds, aes(x = time, ymin=(COV.conf.low * scaleFactor), ymax = (COV.conf.high * scaleFactor), fill = "Survey Effort Proxy"), alpha = 0.4) +
    scale_colour_manual(
      name = NULL,
      values = c("Naive Model" = "turquoise4","IAS First Records" = "turquoise4", "Survey Effort Proxy" = "#8C3330", "GBIF Records" = "#8C3330"),
      breaks = c("IAS First Records", "GBIF Records", "Naive Model", "Survey Effort Proxy"), 
      labels = c("IAS First Records", "GBIF Records", "Naive Model", "Survey Effort Proxy")
    ) +
    scale_fill_manual(
      name = NULL,
      values = c("Naive Model" = "turquoise","IAS First Records" = "white", "Survey Effort Proxy" = "indianred1", "GBIF Records" = "white"),
      breaks = c("IAS First Records", "GBIF Records", "Naive Model", "Survey Effort Proxy"), 
      labels = c("IAS First Records", "GBIF Records", "Naive Model", "Survey Effort Proxy")
    ) +
    scale_y_continuous(name="Annual IAS first records",
                       sec.axis = sec_axis(~./scaleFactor, name="Annual GBIF records", labels = scales::label_number(scale = 1/1e6, suffix = "M")),
                       breaks = scales::breaks_pretty(n = 5), 
                       expand = c(0.005, 0), limits = c(0, NA)) +
    scale_x_continuous(expand = c(0.005, 0), limits = c(0, 51), breaks = c(0, 10, 20, 30, 40, 50), labels = c("1970", "1980", "1990", "2000", "2010", "2020")) + 
    xlab("Year") +
    theme_classic() + 
    theme(axis.title.y.left = element_text(
        colour = "turquoise4",
        angle = 90,
        vjust = 0.5
      ),
      axis.title.y.right = element_text(
        colour = "#8C3330",
        angle = -90,
        vjust = 0.5
      ),
      axis.text.y.left=element_text(color="turquoise4"),
      axis.text.y.right=element_text(color="#8C3330"), 
      legend.position = "inside",
      legend.position.inside = c(0.05, 0.95),
      legend.justification = c("left", "top"), 
      legend.background = element_rect(
        fill = alpha('white', 0.8)), 
      legend.text=element_text(size=rel(0.6)))
  
  return(p)
}
