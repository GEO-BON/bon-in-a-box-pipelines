library(gh)
library(tidyverse)
input <- biab_inputs()
# connect to github repo
files <- gh("GET /repos/{owner}/{repo}/contents/{path}",
            owner = "OHI-Science",
            repo  = "ohi-global",
            path  = "eez/layers")

file_names <- vapply(files, function(x) x$name, character(1))
download_urls <- vapply(files, function(x) x$download_url, character(1))


pressures <- read.csv("https://raw.githubusercontent.com/OHI-Science/ohi-global/draft/eez/conf/pressures_matrix.csv", stringsAsFactors = FALSE, na.strings = c("", "NA"))
print(pressures)

# filter to the goals of interest
bd_pressure_layers <- pressures[pressures$goal %in% c('HAB', 'SPP'), ]
bd_pressure_layers <- bd_pressure_layers[rowSums(!is.na(bd_pressure_layers[, 4:ncol(bd_pressure_layers)])) > 0, ] #take only ones that are greater than 0
print(bd_pressure_layers)

pressure_matrix_path <- file.path(outputFolder, "pressure_matrix_bd.csv")
write.csv(bd_pressure_layers, pressure_matrix_path, row.names=FALSE)
biab_output("pressure_matrix_bd", pressure_matrix_path) 

file_names_pressure <- file_names[
  tolower(tools::file_path_sans_ext(file_names)) %in%
    tolower(colnames(bd_pressure_layers))
]
print(file_names_pressure)
download_urls_pressure <- download_urls[file_names %in% file_names_pressure]

pressure_values <- c()
# load in pressures for most recent year and add to data frame
for (i in seq_along(file_names_pressure)) {
  print(file_names_pressure[i])
  df <- read.csv(download_urls_pressure[i]) 
  if (nrow(df)==0){ # skip if file empty
    next
  }
   df_filt <- df %>% filter(year == max(year)) %>% filter(rgn_id == input$eez_code) %>% rename_with(~ "score", .cols = 3) %>%
  mutate(pressure = sub("\\.csv$", "", file_names_pressure[i], ignore.case = TRUE))
  print(df_filt)
  pressure_values <- rbind(pressure_values, df_filt)
}

pressure_values_path <- file.path(outputFolder, "pressure_values.csv")
write.csv(pressure_values, pressure_values_path)
biab_output("pressure_values", pressure_values_path)

### Now use matrix to calculate the total pressure for each goal
# Load pressure categories script to get social vs ecological pressure categories
pressure_categories <- read.csv("https://raw.githubusercontent.com/OHI-Science/ohi-global/refs/heads/draft/eez/conf/pressure_categories.csv")
pressure_categories <- pressure_categories %>% rename(pressure = layer)
# put matrix into long format
pressure_matrix_long <- bd_pressure_layers %>%
  tidyr::pivot_longer(
    cols = -c(goal, element, element_name),
    names_to  = "pressure",
    values_to = "weight"
  ) %>%
  dplyr::filter(!is.na(weight))
print(pressure_matrix_long)

gamma = input$pressures_gamma

## Now join matrix and values together and categories together
pressure_scores <- pressure_values %>%
  dplyr::inner_join(pressure_matrix_long, by = "pressure") %>%
  group_by(goal, pressure) %>% # average scores within goals and resilience layers
  summarise(
    score = mean(score, na.rm = TRUE),
    weight = first(weight),
    .groups = "drop"
  ) %>% # take the mean of each resilience score within each layer, weight will stay the same
  dplyr::inner_join(pressure_categories, by = "pressure") %>%
  group_by(pressure, goal, category) %>%
  summarise(
    score = sum(score * weight, na.rm = TRUE) /
            sum(weight, na.rm = TRUE),
    .groups = "drop"
  ) %>% # calculate weighted mean
  group_by(goal, category) %>% # average by category (social vs ecological)
  summarise(score = mean(score)) %>%
  pivot_wider(names_from = category, values_from = score) %>%
  group_by(goal) %>%
    summarise(
    score = if (all(c("ecological", "social") %in% names(cur_data()))) {
              gamma * ecological + (1 - gamma) * social
            } else {
              mean(c(ecological, social), na.rm = TRUE)
            },
    .groups = "drop"
  )
print(pressure_scores)

pressure_scores_path <- file.path(outputFolder, "pressure_scores.csv")
write.csv(pressure_scores, pressure_scores_path, row.names=FALSE)
biab_output("pressure_scores", pressure_scores_path)