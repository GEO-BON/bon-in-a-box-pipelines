library(dplyr)

input <- biab_inputs()

# list of countries to calculate Cali fund for
country_list <- read.csv("C:/Users/Samara/Desktop/bon-in-a-box-pipelines/scripts/cali_fund/clean_country_list.csv")

# reading in criterion data
biodiversity_importance <- read.csv("C:/Users/Samara/Desktop/bon-in-a-box-pipelines/scripts/cali_fund/gef_countries.csv")
gr <- read.csv()
gr <- country_list %>%
  mutate(gr = 0.5)
conservation_capacity <- read.csv("C:/Users/Samara/Desktop/bon-in-a-box-pipelines/scripts/cali_fund/capacity.csv")
iplc_tk <- read.csv()
iplc_tk <- country_list %>%
  mutate(iplc_tk = 0.5)

# joining all criterion data to country list
country_data <- country_list %>%
  dplyr::left_join(biodiversity_importance, by = "country_name") %>%
  dplyr::left_join(gr, by = "country_name") %>%
  dplyr::left_join(conservation_capacity, by = "country_name") %>%
  dplyr::left_join(iplc_tk, by = "country_name") %>%
  mutate(gef_allocation = as.numeric(gef_allocation), 
  gr = as.numeric(gr), 
  inverse = as.numeric(inverse), 
  iplc_tk = as.numeric(iplc_tk)) %>%
  rename(biodiversity_importance = gef_allocation,
         gr = gr,
         conservation_capacity = inverse,
         iplc_tk = iplc_tk)

# scale each criterion to a 0-1 range
country_data <- country_data %>%
  dplyr::mutate(
    biodiversity_importance_scaled = (biodiversity_importance - min(biodiversity_importance, na.rm = TRUE)) / (max(biodiversity_importance, na.rm = TRUE) - min(biodiversity_importance, na.rm = TRUE)),
    gr_scaled = (gr - min(gr, na.rm = TRUE)) / (max(gr, na.rm = TRUE) - min(gr, na.rm = TRUE)),
    conservation_capacity_scaled = (conservation_capacity - min(conservation_capacity, na.rm = TRUE)) / (max(conservation_capacity, na.rm = TRUE) - min(conservation_capacity, na.rm = TRUE)),
    iplc_tk_scaled = (iplc_tk - min(iplc_tk, na.rm = TRUE)) / (max(iplc_tk, na.rm = TRUE) - min(iplc_tk, na.rm = TRUE))
  )

# could also be calculated as a percent of the total fund
total_fund <- input$total_fund
base <- (input$base_percent / 100) * total_fund
ceiling <- (input$ceiling_percent / 100) * total_fund

# weights for each criterion
biodiversity_weight <- input$biodiversity_weight
gr_weight <- input$gr_weight
conservation_capacity_weight <- input$conservation_capacity_weight
iplc_tk_weight <- input$iplc_tk_weight

# calculating Cali fund allocation for each country
# currently does not redistribute left over funds if a country hits the ceiling, but this could be added in future iterations
allocate_fund <- function(country_data, total_fund, base_pct, ceiling_pct,
                          biodiversity_weight, gr_weight,
                          conservation_capacity_weight, iplc_tk_weight) {
  n <- nrow(country_data)

  R <- total_fund - n * base

  # weighted composite score
  country_data <- country_data %>%
    dplyr::mutate(
      score = biodiversity_weight * biodiversity_importance_scaled +
        gr_weight * gr_scaled +
        conservation_capacity_weight * conservation_capacity_scaled +
        iplc_tk_weight * iplc_tk_scaled,
      score = tidyr::replace_na(score, 0),
      allocation = pmin(base + R * (score / sum(score)), ceiling)
    )

  # summary of fund utilisation
  total_allocated <- sum(country_data$allocation)
  unspent <- total_fund - total_allocated

  list(
    results = country_data,
    total_allocated = total_allocated,
    unspent = unspent,
    feasible = TRUE
  )
}
cali_fund_allocation <- allocate_fund(
  country_data, total_fund, base, ceiling,
  biodiversity_weight, gr_weight,
  conservation_capacity_weight, iplc_tk_weight
)

# filtering for country of interest
country_name <- input$country_name$country$englishName

cali_fund_allocation_country <- cali_fund_allocation$results %>%
  dplyr::filter(country == country_name) %>%
  dplyr::select(country, allocation)


biab_output("cali_fund_allocation", cali_fund_allocation$results)
biab_output("cali_fund_allocation_country", cali_fund_allocation_country$allocation)
