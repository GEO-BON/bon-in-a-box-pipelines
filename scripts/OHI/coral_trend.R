library(tidyverse)

input <- biab_inputs()

# Load coral trend data
coral_trend <- read_csv("https://raw.githubusercontent.com/OHI-Science/ohi-global/refs/heads/draft/eez/layers/hab_coral_trend.csv")

# Filter for region of interest in the habitat health data
health_filt <- coral_trend |> filter(rgn_id == input$eez_code)
print(health_filt)

coral_trend_path <- file.path(outputFolder, 'coral_trend.csv')
write.csv(health_filt, coral_trend_path, row.names=FALSE)


biab_output("coral_trend", coral_trend_path)
