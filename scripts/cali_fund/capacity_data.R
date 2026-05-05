library(readxl)

country_list <- read.csv("C:/Users/Samara/Desktop/bon-in-a-box-pipelines/scripts/cali_fund/clean_country_list.csv")

raw <- read_excel("C:/Users/Samara/Desktop/bon-in-a-box-pipelines/scripts/cali_fund/Scale of Assessments for RB 1946-2027.xlsx", skip = 2)


# Rename first column
names(raw)[1] <- "country_name"

# Find most recent year column
year_cols <- names(raw)[str_detect(names(raw), "^\\d{4}$")]
most_recent_year <- max(as.numeric(year_cols), na.rm = TRUE)

clean <- raw %>%
  select(
    country_name,
    value = all_of(as.character(most_recent_year))
  ) %>%
  mutate(
    country_name = country_name %>% 
    str_remove_all("\\*") %>%
    str_remove_all("\\*") %>%
      str_remove_all("\\s*\\([^\\)]+\\)") %>%
      str_remove_all("\\s+[a-z]/$") %>%
      str_squish(),
    value = as.character(value) %>%
      str_squish(),
    value = na_if(value, "-"),
    value = parse_number(value)
  ) %>%
  # remove notes/footer starting at Total
  filter(!(country_name == "Total")) %>%
  filter(
    !is.na(country_name),
    country_name != "",
    !is.na(value)
  )

clean_countries <- clean %>%
  filter(country_name %in% country_list$country_name)

inverse <- clean_countries %>%
  mutate(inverse = 1/value) %>%
  select(country_name, inverse)

write.csv(inverse, "C:/Users/Samara/Desktop/bon-in-a-box-pipelines/scripts/cali_fund/capacity.csv", row.names = FALSE)
