## Combine status and trend for each goal with pressures and resilience
library(tidyverse)

input <- biab_inputs()

spp_scores <- read.csv(input$species_scores)
hab_scores <- read.csv(input$habitat_scores)
pressure_scores <- read.csv(input$pressure_scores)
resilience_scores <- read.csv(input$resilience_scores)

spp_scores_wide <- spp_scores %>%
    pivot_wider(names_from = dimension, values_from = score)
spp_scores_wide$weight <- input$weight

hab_scores_wide <- hab_scores %>%
    pivot_wider(names_from = dimension, values_from = score)
hab_scores_wide$weight <- 1-input$weight

scores_comb <- spp_scores_wide %>%
    rbind(hab_scores_wide) %>%
    full_join(pressure_scores, by = "goal") %>%
    rename(pressure = score) %>%
    full_join(resilience_scores, by = "goal") %>%
    rename(resilience = score)

scores_comb$beta <- input$beta
print(scores_comb)

# Calculate OHI for sp and habitat
ohi_scores <-
    scores_comb %>%
    mutate(
        OHI =
            (beta * trend +
                (1 - beta) * (resilience - pressure)
    ) / (1 + beta) ) 

ohi_scores_out <- ohi_scores %>% select(goal, OHI)

ohi_scores_path <- file.path(outputFolder, "ohi_scores_subgoal.csv")
write.csv(ohi_scores_out, ohi_scores_path, row.names=FALSE)
biab_output("ohi_scores_subgoal", ohi_scores_path)


ohi_score <- ohi_scores %>% summarise(OHI = sum(OHI * weight))

biab_output("ohi_score", ohi_score$OHI)
