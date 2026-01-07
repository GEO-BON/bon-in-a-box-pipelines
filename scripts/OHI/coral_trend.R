library(tidyverse)

input <- biab_inputs()

# Load coral trend data
coral_trend <- read_csv("https://raw.githubusercontent.com/OHI-Science/ohi-global/refs/heads/draft/eez/layers/hab_coral_trend.csv")

# Filter trend data by region code
print(input$country_region$country$ISO3)
eez_codes <- read_csv("https://raw.githubusercontent.com/OHI-Science/ohi-global/refs/heads/draft/eez/spatial/regions_list.csv")

# Match up EEZ name to region code
print(input$country_region$country$ISO3)
eez_code_filt <- eez_codes |> filter(eez_iso3 == input$country_region$country$ISO3)
print(eez_code_filt)

# Filter for region of interest in the habitat health data
health_filt <- coral_trend |> filter(rgn_id == eez_code_filt$rgn_id)
print(health_filt)

coral_trend_path <- file.path(outputFolder, 'coral_trend.csv')
write.csv(health_filt, coral_trend_path, row.names=FALSE)


biab_output("coral_trend", coral_trend_path)
