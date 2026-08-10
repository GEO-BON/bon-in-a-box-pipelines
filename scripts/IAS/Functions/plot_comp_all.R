## ---------------------------------------------------------
## PLOTS OF MODELS - PLOTTING NAIVE + ALL SNCS IN ONE PLOT
## ---------------------------------------------------------

plot_comp_all <- function() {
  
  get_snc <- function(name) {
    if (exists(name, envir = .GlobalEnv)) {
      obj <- get(name, envir = .GlobalEnv)
      if (!is.null(obj) && !all(is.na(obj))) return(obj)
    }
    return(NULL)
  }
  
  snc_list <- list(
    ConstDet = get_snc("ConstDet"),
    SC = get_snc("SC"),
    Sampling = get_snc("Sampling"))
  
  snc_data <- lapply(snc_list, function(obj) {
    if (is.null(obj)) return(NULL)
    tibble::tibble(
      time = seq_along(obj[["records"]]) - 1,
      fitted = obj$predict$mean
    )
  })
  
  ## naive model stuff:
  glm.data <- tibble::tibble(
    time = input_Anywhere$time,
    n = input_Anywhere$n
  )
  
  colour_values <- c(
    "First Records" = "black",
    "Naive Model" = "turquoise4"
  )
  linetype_values <- c(
    "First Records" = "dashed",
    "Naive Model" = "solid"
  )
  breaks_vec <- c("First Records", "Naive Model")
  label_vec <- c("First Records", "Naive Model")
  
  
  # Start ggplot
  p <- ggplot() +
    geom_line(data = glm.data, aes(x = time, y = n, colour = "First Records", linetype = "First Records")) +
    geom_line(
      data = glm.data, stat = "smooth", method = "glm", method.args = list(family = "poisson"),
      formula = y ~ x, aes(x = time, y = n, colour = "Naive Model", linetype = "Naive Model"),
      se = FALSE, linewidth = 0.8, alpha = 1
    )
  
  # add model lines if model objects exist in the order I want them to appear in the plot key
  
  ## Constant Detection
  if (!is.null(snc_data$ConstDet))
    p <- p + geom_line(data = snc_data$ConstDet, aes(x = time, y = fitted, colour = "ConstDet", linetype = "ConstDet"), linewidth = 0.8, alpha = 1)
  if (!is.null(snc_data$ConstDet)) {
    colour_values["ConstDet"] <- "#ed254e"
    linetype_values["ConstDet"] <- "twodash"
    breaks_vec <- c(breaks_vec, "ConstDet")
    label_vec <- c(label_vec, "Constant Detection Model")
  }
  
  ## SC
  if (!is.null(snc_data$SC))
    p <- p + geom_line(data = snc_data$SC, aes(x = time, y = fitted, colour = "SC Model", linetype = "SC Model"), linewidth = 0.8, alpha = 1)
  if (!is.null(snc_data$SC)) {
    colour_values["SC Model"] <- "#F69E34"
    linetype_values["SC Model"] <- "longdash"
    breaks_vec <- c(breaks_vec, "SC Model")
    label_vec  <- c(label_vec, "S&C Model")
  }
  
  ## Sampling
  if (!is.null(snc_data$Sampling))
    p <- p + geom_line(data = snc_data$Sampling, aes(x = time, y = fitted, colour = "Sampling Model", linetype = "Sampling Model"), linewidth = 0.8, alpha = 1)
  if (!is.null(snc_data$Sampling)) {
    colour_values["Sampling Model"] <- "#A6D175"
    linetype_values["Sampling Model"] <- "dotdash"
    breaks_vec <- c(breaks_vec, "Sampling Model")
    label_vec <- c(label_vec, "Sampling Model" )
  }
  
  
  # Apply legend scales
  p <- p +
    scale_colour_manual(name = NULL, values = colour_values, breaks = breaks_vec, labels = label_vec) +
    scale_linetype_manual(name = NULL, values = linetype_values, breaks = breaks_vec, labels = label_vec) +
    scale_x_continuous(
      expand = c(0, 0), limits = c(0, 51),
      breaks = c(0.01, 10, 20, 30, 40, 50),
      labels = c("1970", "1980", "1990", "2000", "2010", "2020")
    ) +
    scale_y_continuous(
      expand = c(0, 0), limits = c(0, NA),
      breaks = scales::breaks_pretty(n = 5),
      labels = scales::label_comma()
    ) +
    ylab("Annual IAS first records") +
    xlab("Year") +
    theme_classic() +
    theme(
      legend.position = "inside",
      legend.position.inside = c(0.95, 0.95),
      legend.justification = c("right", "top"),
      legend.background = element_rect(fill = alpha("white", 0.9)),
      legend.text = element_text(size = rel(0.6))
    )
  
  return(p)
}

