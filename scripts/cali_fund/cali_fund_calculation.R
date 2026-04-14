library(dplyr)

input <- biab_inputs()

# reading in criterion data
biodiversity_iportance <- read.csv(input$biodiversity_importance)
gr <- read.csv(input$gr)
conservation_capacity <- read.csv(input$conservation_capacity)
iplc_tk <- read.csv(input$iplc_tk)

# list of countries to calculate Cali fund for
country_list <- read.csv(input$country_list)

# joining all criterion data to country list
country_data <- country_list %>%
  dplyr::left_join(biodiversity_iportance, by = "country") %>%
  dplyr::left_join(gr, by = "country") %>%
  dplyr::left_join(conservation_capacity, by = "country") %>%
  dplyr::left_join(iplc_tk, by = "country")

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
