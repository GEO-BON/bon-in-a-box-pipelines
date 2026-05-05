library(readxl)

country_list <- read.csv("C:/Users/Samara/Desktop/bon-in-a-box-pipelines/scripts/cali_fund/clean_country_list.csv")

gef <- read_excel("C:/Users/Samara/Desktop/bon-in-a-box-pipelines/scripts/cali_fund/GEF-8 numbers.xlsx")

gef_countries <- gef %>%
  filter(`Country` %in% country_list$country_name) %>%
  select(`Country`, `Total Normalised Weighted Terrestrial`) %>%
  rename(country_name = `Country`, gef_allocation = `Total Normalised Weighted Terrestrial`)

write.csv(gef_countries, "C:/Users/Samara/Desktop/bon-in-a-box-pipelines/scripts/cali_fund/gef_countries.csv", row.names = FALSE)
