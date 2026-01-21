library(gh)
library(tidyverse)
input <- biab_inputs

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

bd_c_layers <- resilience[resilience$goal %in% c('HAB', 'SPP'), ]
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

# load resilience files
resilience_values <- list()
# load in resilience for most recent year and add to data frame
for (i in seq_along(file_names_resilience)) {
  df <- read.csv(download_urls_resilience[i]) %>% filter(year == max(year)) %>% filter(rgn_id == input$eez_code) %>%
  mutate(resilience = sub("\\.csv$", "", file_names_resilience[i], ignore.case = TRUE))
  resilience_values <- rbind(resilience_values, df)
}

resilience_values_path <- file.path(outputFolder, "resilience_values.csv")
write.csv(resilience_values, resilience_values_path)
biab_output("resilience_values", resilience_values_paths)

