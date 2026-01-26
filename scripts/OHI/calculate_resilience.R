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

# load  resilience and filter to the goals of interest
resilience <- read.csv("https://raw.githubusercontent.com/OHI-Science/ohi-global/draft/eez/conf/resilience_matrix.csv", stringsAsFactors = FALSE, na.strings = c("", "NA"))
print(resilience)

bd_resilience_layers <- resilience[resilience$goal %in% c('HAB', 'SPP'), ]

bd_resilience_layers <- bd_resilience_layers[
  rowSums(bd_resilience_layers[, 4:ncol(bd_resilience_layers)] == "x", na.rm = TRUE) > 0,
]

resilience_matrix_path <- file.path(outputFolder, "resilience_matrix_bd.csv")
write.csv(bd_resilience_layers, resilience_matrix_path, row.names=FALSE)
biab_output("resilience_matrix_bd", resilience_matrix_path) 

cols <- paste(colnames(bd_resilience_layers), collapse="|")
file_names_resilience <- file_names[str_detect(file_names, regex(cols, ignore_case = TRUE))]
print(file_names_resilience)
download_urls_resilience <- download_urls[file_names %in% file_names_resilience]
print(download_urls_resilience)
print(class(input$eez_code))
# load resilience files
resilience_values <- list()
# load in resilience for most recent year and add to data frame
for (i in seq_along(file_names_resilience)) {
  print(file_names_resilience[i])
  df <- read.csv(download_urls_resilience[i]) 
  if (nrow(df)==0){ # skip if file empty
    next
  }
  df_filt <- df %>% filter(year == max(year)) %>% filter(rgn_id == input$eez_code) %>% rename_with(~ "value", .cols = 3) %>%
  mutate(resilience = sub("\\.csv$", "", file_names_resilience[i], ignore.case = TRUE))
  print(df_filt)
  resilience_values <- rbind(resilience_values, df_filt)
}

resilience_values_path <- file.path(outputFolder, "resilience_values.csv")
write.csv(resilience_values, resilience_values_path)
biab_output("resilience_values", resilience_values_path)

# Calculate resilience score for each aspect of biodiversity
# All weights are 1 (in conf/resilience_vategories.csv) so I can take the mean of each layer for each aspect of the biodiversity goal
resilience_matrix_long <- bd_resilience_layers %>%
  tidyr::pivot_longer(
    cols = -c(goal, element),
    names_to  = "resilience",
    values_to = "include"
  ) %>%
  dplyr::filter(!is.na(include))
  print(resilience_matrix_long)

# Put resilience matrix in long format to assess which layers are applicable to which goal and join to values
# Load resilience categories csv to get info on weights and whether it is social or ecological
resilience_categories <- read.csv("https://raw.githubusercontent.com/OHI-Science/ohi-global/refs/heads/draft/eez/conf/resilience_categories.csv")
resilience_categories <- resilience_categories %>% rename(resilience = layer)
print(resilience_categories)
gamma = input$resilience_gamma

resilience_scores <- resilience_values %>%
  inner_join(resilience_matrix_long, by = "resilience") %>%
  group_by(goal, resilience) %>% # average scores within goals and resilience layers
  summarize(score = mean(value)) %>% # take the mean of each resilience score within each layer
  inner_join(resilience_categories, by = "resilience") %>% # join with resilience categories
  mutate(score = score * weight) %>% # multiply it by the weight of the layer (1 for all in this case)
  group_by(goal, category) %>% # average by category (social vs ecological)
  summarise(score = mean(score)) %>%
  pivot_wider(names_from = category, values_from = score) %>%
  group_by(goal) %>%
  summarise(
    score = if (all(c("ecological","social") %in% names(cur_data()))) {
              gamma * ecological + (1 - gamma) * social
            } else {
              mean(c(ecological, social), na.rm = TRUE)
            },
    .groups = "drop"
  ) # finally use gamma parameter to calculate the resilience for each goal

print(resilience_scores)


resilience_scores_path <- file.path(outputFolder, "resilience_scores.csv")
write.csv(resilience_scores, resilience_scores_path, row.names=FALSE)
biab_output("resilience_scores", resilience_scores_path)