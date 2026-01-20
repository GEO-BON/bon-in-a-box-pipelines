## Script to load pressure and resiliences matrices and integrate them into OHI scoring

# connect to github repo
files <- gh("GET /repos/{owner}/{repo}/contents/{path}",
            owner = "OHI-Science",
            repo  = "ohi-global",
            path  = "eez/layers")


# load pressure and resilience and filter to the goals of interest
resilience <- read.csv("https://raw.githubusercontent.com/OHI-Science/ohi-global/draft/eez/conf/resilience_matrix.csv", stringsAsFactors = FALSE, na.strings = c("", "NA"))
print(resilience)

bd_resilience_layers <- resilience[resilience$goal %in% c('HAB', 'SPP'), ]
bd_resilience_layers <- bd_resilience_layers[
  rowSums(bd_resilience_layers[, 4:ncol(bd_resilience_layers)] == "x", na.rm = TRUE) > 0,
]

# load resilience files
cols <- paste(colnames(bd_resilience_layers), collapse="|")
file_names_resilience <- file_names[str_detect(file_names, regex(cols, ignore_case = TRUE))]
print(file_names_resilience)
download_urls_resilience <- download_urls[file_names %in% file_names_resilience]




pressures <- read.csv("https://raw.githubusercontent.com/OHI-Science/ohi-global/draft/eez/conf/pressures_matrix.csv", stringsAsFactors = FALSE, na.strings = c("", "NA"))
print(pressures)

# filter to the goals of interest
bd_pressure_layers <- pressures[pressures$goal %in% c('HAB', 'SPP'), ]
bd_pressure_layers <- bd_pressure_layers[rowSums(!is.na(bd_pressure_layers[, 4:ncol(bd_pressure_layers)])) > 0, ] #take only ones that are greater than 0


pressures_file_paths <- c()
for (i in seq_along(file_names_pressure)) {
  dest <- file.path(outputFolder, file_names_pressure[i])
  download.file(download_urls_pressure[i], destfile = dest, mode = "wb")
  cat("Saved:", dest, "\n")
  pressures_file_paths <- rbind(pressures_file_paths, dest)
}



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