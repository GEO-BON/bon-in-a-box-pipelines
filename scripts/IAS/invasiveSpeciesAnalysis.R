if (!requireNamespace("alien", quietly = TRUE)) {
  install.packages("alien")
}
library(alien)
library(readr)
library(dplyr)
library(lubridate)
library(ggplot2)

input <- biab_inputs()

# Load your GBIF invasive species first records
gbif <- read_tsv(input$observations_file, show_col_types = FALSE)

glimpse(gbif)
# Ensure 'year' column is integer and drop rows with NA years
# gbif <- gbif %>%
#   mutate(year = as.integer(year)) %>%
#   filter(!is.na(year))

print(head(gbif))

# # Get first recorded year per species
# first_records <- gbif %>%
#   group_by(scientific_name) %>%
#   summarise(first_year = min(year, na.rm = TRUE), .groups = "drop")

# Count how many species were first recorded in each year
yearly_counts <- gbif %>%
  count(gimme, name = "new_species") %>%
  arrange(gimme)

# Define full year range
year_range <- input$min_year:input$max_year

# Fill missing years with zero counts
complete_yearly_counts <- tibble(year = year_range) %>%
  left_join(yearly_counts, by = c("year" = "gimme")) %>%
  mutate(new_species = ifelse(is.na(new_species), 0, new_species))

# Prepare inputs for snc
data <- complete_yearly_counts$new_species
print(data)
years <- complete_yearly_counts$year
print(years)

#Run simple model
model_simple <- snc(y = data, control = list(maxit = 1e4))
#alternate inputs:
#pi = ~1 (constant detection model)
#mu = ~1 (constant introduction model)

print(summary(model_simple))

if (model_simple$convergence != 0) {
  cat("Warning: Optimation algorithm failed to converge and returned a convergence of", model_simple$convergence, "\n")
}

cat("Log likelihood:", model_simple$`log-likelihood`, "\n")

if (input$plot_type == "annual") {
  bool <- FALSE
} else if (input$plot_type == "cumulative") {
  bool <- TRUE
}

# Find positions of years divisible by 20
year_break_indices <- which(years %% 20 == 0)
year_break_labels <- years[year_break_indices]

final_plot <- plot_snc(model_simple, cumulative = bool) +
  xlab("Year of first record in data") +
  labs(title = "Number of introduced invasive alien species over time") +
  scale_x_continuous(
    breaks = year_break_indices,  # index positions on x-axis
    labels = year_break_labels    # actual year values
  ) +
  theme(plot.title = element_text(hjust = 0.5, face = "bold"))

result_plot_path <- file.path(outputFolder, "final_plot.png")
ggsave(result_plot_path, final_plot)
biab_output("result_plot", result_plot_path)

#Run constant detection model
# model_constant_detection <- snc(y = data, pi = ~1, control = list(maxit = 1e4))

# print(summary(model_constant_detection))

# if (model_constant_detection$convergence != 0) {
#   cat("Warning: Optimation algorithm failed to converge and returned a convergence of", model_constant_detection$convergence, "\n")
# }

# cat("Log likelihood:", model_constant_detection$`log-likelihood`, "\n")

# detection_plot <- plot_snc(model_constant_detection, cumulative = bool) +
#   xlab("Year of first record in data")

# detection_plot_path <- file.path(outputFolder, "detection_plot.png")
# ggsave(detection_plot_path, detection_plot)
# biab_output("detection_plot", detection_plot_path)
