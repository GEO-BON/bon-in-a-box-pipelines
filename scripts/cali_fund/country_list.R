library(readxl)
library(tidyverse)

country_list <- read_xls("C:/Users/Samara/Desktop/bon-in-a-box-pipelines/scripts/cali_fund/List of countries eligible for funding_April-2026.xls")
head(country_list)

# Function to test if something is a number
is_number <- function(x) {
  !is.na(suppressWarnings(as.numeric(x)))
}

# Look across every adjacent column pair:
# left column = number, right column = country name
clean_country_list <- map_dfr(2:ncol(country_list), function(i) {
  
  left_col  <- country_list[[i - 1]]
  right_col <- country_list[[i]]
  
  tibble(
    number = left_col,
    country_name = right_col
  ) %>%
    mutate(
      number = suppressWarnings(as.numeric(number)),
      country_name = country_name %>%
        as.character() %>%
        str_remove_all("\\*") %>%   # <-- remove asterisks
        str_trim()
    ) %>%
    filter(
      !is.na(number),
      !is.na(country_name),
      country_name != "",
      str_detect(country_name, "[A-Za-z]")
    )
}) %>%
  select(country_name) %>%
  distinct() %>%
  arrange(country_name)

head(clean_country_list)

# Save checklist
write.csv(clean_country_list, "C:/Users/Samara/Desktop/bon-in-a-box-pipelines/scripts/cali_fund/clean_country_list.csv", row.names = FALSE)
