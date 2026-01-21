library(tidyverse)

input <- biab_inputs()

print(input$country_region$country$ISO3)
eez_codes <- read_csv("https://raw.githubusercontent.com/OHI-Science/ohi-global/refs/heads/draft/eez/spatial/regions_list.csv")
print(eez_codes)
# Match up EEZ name to region code

eez_code_filt <- eez_codes |> filter(eez_iso3 == input$country_region$country$ISO3)
print(eez_code_filt)

biab_output("eez_code", eez_code_filt$rgn_id)