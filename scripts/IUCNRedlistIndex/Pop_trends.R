library(magrittr)
library(dplyr)

input <- biab_inputs()

splist <- read.csv(input$splist)

token <- Sys.getenv("IUCN_TOKEN")
if (token == "") {
  biab_error_stop("Please specify an IUCN token in your environment file")
}


# Extract the red list population trends
sp_increasing <- rredlist::rl_pop_trends(key = token, code = "0", latest = TRUE, scope_code = 1)$assessments 
sp_increasing <- sp_increasing %>% dplyr::distinct(sis_taxon_id, .keep_all = TRUE)

sp_decreasing <- rredlist::rl_pop_trends(key = token, code = "1", latest = TRUE, scope_code = 1)$assessments 
sp_decreasing <- sp_decreasing %>% dplyr::distinct(sis_taxon_id, .keep_all = TRUE)

sp_stable <- rredlist::rl_pop_trends(key = token, code = "2", latest = TRUE, scope_code = 1)$assessments 
sp_stable <- sp_stable %>% dplyr::distinct(sis_taxon_id, .keep_all = TRUE)

sp_unknown <- rredlist::rl_pop_trends(key = token, code = "3", latest = TRUE, scope_code = 1)$assessments 
sp_unknown <- sp_unknown %>% dplyr::distinct(sis_taxon_id, .keep_all = TRUE)


print(sprintf("Number of species impcreasing in total: %s", nrow(sp_increasing)))

# Filter the species list from the country of interest with the list of improving species
sp_increasing_country <- splist %>% dplyr::filter(sis_taxon_id %in% sp_increasing$sis_taxon_id)
sp_decreasing_country <- splist %>% dplyr::filter(sis_taxon_id %in% sp_decreasing$sis_taxon_id)
sp_stable_country <- splist %>% dplyr::filter(sis_taxon_id %in% sp_stable$sis_taxon_id)
sp_unknown_country <- splist %>% dplyr::filter(sis_taxon_id %in% sp_unknown$sis_taxon_id)

print(sp_increasing_country)
total_sp <- nrow(splist)
num_increasing <- nrow(sp_increasing_country)
num_decreasing <- nrow(sp_decreasing_country)
num_stable <- nrow(sp_stable_country)
num_unknown <- nrow(sp_unknown_country)

print(paste0("Number of species with increasing populations:", num_increasing))
print(paste0("Number of species with decreasing populations:", num_decreasing))
print(paste0("Number of species with stable populations:", num_stable))
print(paste0("Number of species with unknown population trends:", num_unknown))

total <- num_increasing + num_decreasing + num_stable + num_unknown
print(total)
print(total_sp)

percentage_increasing <- ifelse(num_increasing == 0, 0, round((num_increasing / total_sp) * 100, 2))
percentage_decreasing <- ifelse(num_decreasing == 0, 0, round((num_decreasing / total_sp) * 100, 2))
percentage_stable <- ifelse(num_stable == 0, 0, round((num_stable / total_sp) * 100, 2))
percentage_unknown <- ifelse(num_unknown == 0, 0, round((num_unknown / total_sp) * 100, 2))

trend <- c("increasing", "decreasing", "stable", "unknown")
percentage <- c(percentage_increasing, percentage_decreasing, percentage_stable, percentage_unknown)
number <- c(num_increasing, num_decreasing, num_stable, num_unknown)

pop_trends <- data.frame(trend = trend, percentage = percentage, number = number)

print(pop_trends)
biab_output("population_trend_percent", pop_trends)


