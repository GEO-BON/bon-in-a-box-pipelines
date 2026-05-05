library(readxl)

country_list <- read.csv("/Users/samaramanzin/Downloads/clean_country_list.csv")

gef <- read_excel("/Users/samaramanzin/Downloads/GEF-8 numbers.xlsx")

gef_countries <- gef %>%
  filter(`Country` %in% country_list$country_name) %>%
  select(`Country`, `Total Normalised Weighted Terrestrial`) %>%
  rename(country_name = `Country`, gef_allocation = `Total Normalised Weighted Terrestrial`)

write.csv(gef_countries, "/Users/samaramanzin/Downloads/gef_countries.csv", row.names = FALSE)
