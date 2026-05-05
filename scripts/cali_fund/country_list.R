library(readxl)
library(tidyverse)

input <- biab_inputs()

country_list <- read.csv(input$country_list)
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

path <- file.path(outputFolder, "clean_country_list.csv")

# Save checklist
write.csv(clean_country_list, path)
biab_output("clean_country_list", path)