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

cols <- paste(colnames(bd_pressure_layers), collapse="|")
file_names_pressure <- file_names[str_detect(file_names, regex(cols, ignore_case = TRUE))]
print(file_names_pressure)
download_urls_pressure <- download_urls[file_names %in% file_names_pressure]

pressure_values <- list()
# load in pressures for most recent year and add to data frame
for (i in seq_along(file_names_pressure)) {
  df <- read.csv(download_urls_pressure[i]) %>% filter(year == max(year)) %>% filter(rgn_id == input$eez_code) %>%
  mutate(pressure = sub("\\.csv$", "", file_names_pressure[i], ignore.case = TRUE))
  pressure_values <- rbind(pressure_values, df)
}

pressure_values_path <- file.path(outputFolder, "pressure_values.csv")
write.csv(pressure_values, pressure_values_path)
biab_output("pressure_values", pressure_values_paths)














# FROM CHAT GPT:

# Weighted function to calculate pressure
calculate_weighted_pressure <- function(data_layers, matrix_file, goal_nm) {
  
  # 1. Filter matrix for your goal
  # data_layers: a dataframe with 'layer' (name) and 'value' (0-1)
  # matrix_file: the csv showing weights (0, 1, 2, 3)
  
  weights <- matrix_file %>%
    filter(goal == goal_nm) %>%
    pivot_longer(cols = -c(goal, element), names_to = "layer", values_to = "weight") %>%
    filter(weight > 0)
  
  # 2. Join weights with your actual data values
  combined <- weights %>%
    inner_join(data_layers, by = "layer")
  
  # 3. Calculate Weighted Average
  # Formula: Sum(value * weight) / Sum(weight)
  p_score <- sum(combined$value * combined$weight) / sum(combined$weight)
  
  return(p_score)
}



# Weighteds function to calculate resilience
calculate_weighted_resilience <- function(res_data, matrix_file, goal_nm) {
  
  # Filter matrix to find which resilience measures apply to the goal
  res_weights <- matrix_file %>%
    filter(goal == goal_nm) %>%
    pivot_longer(cols = -c(goal, element), names_to = "layer", values_to = "weight") %>%
    filter(weight > 0)
  
  combined <- res_weights %>%
    inner_join(res_data, by = "layer")
  
  # Calculate mean resilience for the goal
  r_score <- mean(combined$value, na.rm = TRUE)
  
  return(r_score)
}

### Note if there are different habitats you have to weight by extentß