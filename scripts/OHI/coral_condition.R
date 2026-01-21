library(tidyverse)

input <- biab_inputs()
# Habitat health data
health <- read_csv("https://raw.githubusercontent.com/OHI-Science/ohi-global/refs/heads/draft/eez/layers/hab_coral_health.csv")
print(health)

# Filter for region of interest in the habitat health data
health_filt <- health |> filter(rgn_id == input$eez_code)
print(health_filt)

coral_condition_path <- file.path(outputFolder, 'coral_condition.csv')
write.csv(health_filt, coral_condition_path, row.names=FALSE)


biab_output("coral_health", coral_condition_path)