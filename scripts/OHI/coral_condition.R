library(tidyverse)

input <- biab_inputs()
# Habitat health data
health <- read_csv("https://raw.githubusercontent.com/OHI-Science/ohi-global/refs/heads/draft/eez/layers/hab_coral_health.csv")
print(health)

# Table of EEZs and codes reference
eez_codes <- read_csv("https://raw.githubusercontent.com/OHI-Science/ohi-global/refs/heads/draft/eez/spatial/regions_list.csv")
print("eez codes")
print(eez_codes)

# Match up EEZ name to region code
print(input$country_region$country$ISO3)
eez_code_filt <- eez_codes |> filter(eez_iso3 == input$country_region$country$ISO3)
print(eez_code_filt)

# Filter for region of interest in the habitat health data
health_filt <- health |> filter(rgn_id == eez_code_filt$rgn_id)
print(health_filt)

coral_condition_path <- file.path(outputFolder, 'coral_condition.csv')
write.csv(health_filt, coral_condition_path, row.names=FALSE)


biab_output("coral_health", coral_condition_path)