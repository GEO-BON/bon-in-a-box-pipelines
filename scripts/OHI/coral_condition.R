library(readr)      # for read_csv()
library(raster)
library(here)
library(sf)
library(fasterize)
library(tidyverse)
library(mapview)
library(sp)

# Habitat health data
health <- read_csv("https://raw.githubusercontent.com/OHI-Science/ohiprep_v2025/refs/heads/main/globalprep/hab_coral/v2012/data/habitat_health_coral_updated.csv")

health_old_gf <- read_csv("https://raw.githubusercontent.com/OHI-Science/ohiprep_v2025/refs/heads/main/globalprep/hab_coral/v2012/data/health_coral_gf.csv") %>%
  left_join(rgns_eez)

# Table of EEZs and codes reference
eez_codes <- read_csv("https://github.com/OHI-Science/ohiprep_v2025/blob/main/globalprep/supplementary_information/v2018/rgn_eez_v2013a_synonyms.csv")

eez <- input$eez_polygon

# Extent data
extent <- input$extent_data

# Match up EEZ name to region code


# Filter for EEZ of interest in habitat health data
health <- health ()

# GCRMN regions
gcrmn_regions <- st_read("https://github.com/GCRMN/gcrmn_regions/blob/main/data/gcrmn-regions/gcrmn_regions.shp")

# Intersection of the region and the EEZ of choice
intersections <- st_intersection(
  eez %>% select(rgn_id, rgn_name, geometry), 
  gcrmn_regions %>% select(region, geometry)
)

# Area of overlap:
intersections <- intersections %>%
  mutate(area_overlap = st_area(geometry))

# Join to health data
regions_health <- left_join(intersections, health, by= "rgn_id")

# Subtract percent change
regions_health <- regions_health %>%
  mutate(adjusted_health = if_else(
    region == "Brazil",        # condition (CHANGE THIS TO IF IT IS POSITIVE)
    health + (health*region_number),            # if TRUE → add
    health - (health*region_number)             # if FALSE → subtract
  ))

# Remove geometry column
regions_health <- regions_health %>% st_drop_geometry()

# Rename columns
regions_health <- regions_health %>%
  rename(
    old_health = health,
    health = adjusted_health
  )

  # Write file:
health <- regions_health %>%
  dplyr::select(rgn_id, habitat, health) %>%
  mutate(year = 2025)

coral_condition_path <- file.path(outputFolder, 'coral_condition.csv')
write.csv(health, coral_condition_path, row.names=FALSE)

biab_output("coral_health", coral_condition_path)