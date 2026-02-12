## Load libraries ###
packagesList <- list("magrittr") # Explicitly list packages needed that must be fully loaded in the environment. Functions from other libraries will be accessible via '::'.
lapply(packagesList, library, character.only = TRUE) # Load explicitly listed libraries

input <- biab_inputs()

token <- Sys.getenv("IUCN_TOKEN")
if (token == "") {
  biab_error_stop("Please specify an IUCN token in your environment file")
}

habitats <- input$habitat
print(class(habitats))
if (length(habitats) == 0) {
  biab_error_stop("Please select a habitat")
}

biab_output("habitats", habitats)

skip <- FALSE
if ("Do not filter by habitat" %in% habitats) {
  if (length(habitats) > 1) {
    biab_error_stop("Cannot select more than one option when selecting 'Don't filter by habitat'")
  }
  skip <- TRUE

  IUCN_habitat <- data.frame()
  IUCN_habitat_splist_path <- file.path(outputFolder, paste0("IUCN_habitat_splist", ".csv")) # Define the file path
  write.csv(IUCN_habitat, IUCN_habitat_splist_path, row.names = F) # write result
  biab_output("IUCN_habitat_splist", IUCN_habitat_splist_path)

  citation <- "No data retrieved based on habitat, as selected by the user"
  biab_output("api_citation", citation)
}

IUCN_habitats <- rredlist::rl_habitats(key = token)
IUCN_habitat_splist <- data.frame()

if ("Marine" %in% habitats) {
  habitats <- habitats[habitats != "Marine"]
  marine_habitats <- c(
        "Marine Neritic",
        "Marine Neritic - Pelagic",
        "Marine Neritic - Subtidal Rock and Rocky Reefs",
        "Marine Neritic - Subtidal Loose Rock/pebble/gravel",
        "Marine Neritic - Subtidal Sandy",
        "Marine Neritic - Subtidal Sandy-Mud",
        "Marine Neritic - Subtidal Muddy",
        "Marine Neritic - Macroalgal/Kelp",
        "Marine Neritic - Coral Reef",
        "Outer Reef Channel",
        "Back Slope",
        "Foreslope (Outer Reef Slope)",
        "Lagoon",
        "Inter-Reef Soft Substrate",
        "Inter-Reef Rubble Substrate",
        "Marine Neritic - Seagrass (Submerged)",
        "Marine Neritic - Estuaries",
        "Marine Oceanic",
        "Marine Oceanic - Epipelagic (0-200m)",
        "Marine Oceanic - Mesopelagic (200-1000m)",
        "Marine Oceanic - Bathypelagic (1000-4000m)",
        "Marine Oceanic - Abyssopelagic (4000-6000m)",
        "Marine Deep Benthic",
        "Marine Deep Benthic - Continental Slope/Bathyl Zone (200-4,000m)",
        "Hard Substrate",
        "Soft Substrate",
        "Marine Deep Benthic - Abyssal Plain (4,000-6,000m)",
        "Marine Deep Benthic - Abyssal Mountain/Hills (4,000-6,000m)",
        "Marine Deep Benthic - Hadal/Deep Sea Trench (>6,000m)",
        "Marine Deep Benthic - Seamount",
        "Marine Deep Benthic - Deep Sea Vents (Rifts/Seeps)",
        "Marine Intertidal",
        "Marine Intertidal - Rocky Shoreline",
        "Marine Intertidal - Sandy Shoreline and/or Beaches, Sand Bars, Spits, Etc",
        "Marine Intertidal - Shingle and/or Pebble Shoreline and/or Beaches",
        "Marine Intertidal - Mud Flats and Salt Flats",
        "Marine Intertidal - Salt Marshes (Emergent Grasses)",
        "Marine Intertidal - Tidepools",
        "Marine Intertidal - Mangrove Submerged Roots",
        "Marine Coastal/Supratidal",
        "Marine Coastal/Supratidal - Sea Cliffs and Rocky Offshore Islands",
        "Marine Coastal/supratidal - Coastal Caves/Karst",
        "Marine Coastal/Supratidal - Coastal Sand Dunes",
        "Marine Coastal/Supratidal - Coastal Brackish/Saline Lagoons/Marine Lakes",
        "Marine Coastal/Supratidal - Coastal Freshwater Lakes",
        "Artificial/Marine - Marine Anthropogenic Structures",
        "Artificial/Marine - Mariculture Cages",
        "Artificial/Marine - Mari/Brackishculture Ponds"
    )
    habitats <- c(habitats, marine_habitats)
}

if ("Terrestrial" %in% habitats) {
    habitats <- habitats[habitats != "Terrestrial"]
    ter_habitats <- c(
        "Forest",
        "Forest - Boreal",
        "Forest - Subarctic",
        "Forest - Subantarctic",
        "Forest - Temperate",
        "Forest - Subtropical/Tropical Dry",
        "Forest - Subtropical/Tropical Moist Lowland",
        "Forest - Subtropical/Tropical Mangrove Vegetation Above High Tide Level",
        "Forest - Subtropical/Tropical Swamp",
        "Forest - Subtropical/Tropical Moist Montane",
        "Savanna",
        "Savanna - Dry",
        "Savanna - Moist",
        "Shrubland",
        "Shrubland - Subarctic",
        "Shrubland - Subantarctic",
        "Shrubland - Boreal",
        "Shrubland - Temperate",
        "Shrubland - Subtropical/Tropical Dry",
        "Shrubland - Subtropical/Tropical Moist",
        "Shrubland - Subtropical/Tropical High Altitude",
        "Shrubland - Mediterranean-type Shrubby Vegetation",
        "Grassland",
        "Grassland - Tundra",
        "Grassland - Subarctic",
        "Grassland - Subantarctic",
        "Grassland - Temperate",
        "Grassland - Subtropical/Tropical Dry",
        "Grassland - Subtropical/Tropical Seasonally Wet/Flooded",
        "Grassland - Subtropical/Tropical High Altitude",
        "Wetlands (inland)",
        "Wetlands (inland) - Permanent Rivers/Streams/Creeks (includes waterfalls)",
        "Wetlands (inland) - Seasonal/Intermittent/Irregular Rivers/Streams/Creeks",
        "Wetlands (inland) - Shrub Dominated Wetlands",
        "Wetlands (inland) - Bogs, Marshes, Swamps, Fens, Peatlands",
        "Wetlands (inland) - Permanent Freshwater Lakes (over 8ha)",
        "Wetlands (inland) - Seasonal/Intermittent Freshwater Lakes (over 8ha)",
        "Wetlands (inland) - Permanent Freshwater Marshes/Pools (under 8ha)",
        "Wetlands (inland) - Seasonal/Intermittent Freshwater Marshes/Pools (under 8ha)",
        "Wetlands (inland) - Freshwater Springs and Oases",
        "Wetlands (inland) - Tundra Wetlands (incl. pools and temporary waters from snowmelt)",
        "Wetlands (inland) - Alpine Wetlands (includes temporary waters from snowmelt)",
        "Wetlands (inland) - Geothermal Wetlands",
        "Wetlands (inland) - Permanent Inland Deltas",
        "Wetlands (inland) - Permanent Saline, Brackish or Alkaline Lakes",
        "Wetlands (inland) - Seasonal/Intermittent Saline, Brackish or Alkaline Lakes and Flats",
        "Wetlands (inland) - Permanent Saline, Brackish or Alkaline Marshes/Pools",
        "Wetlands (inland) - Seasonal/Intermittent Saline, Brackish or Alkaline Marshes/Pools",
        "Wetlands (inland) - Karst and Other Subterranean Hydrological Systems (inland)",
        "Rocky areas (eg. inland cliffs, mountain peaks)",
        "Caves and Subterranean Habitats (non-aquatic)",
        "Caves and Subterranean Habitats (non-aquatic) - Caves",
        "Caves and Subterranean Habitats (non-aquatic) - Other Subterranean Habitats",
        "Desert",
        "Desert - Hot",
        "Desert - Temperate",
        "Desert - Cold",
        "Artificial/Terrestrial",
        "Artificial/Terrestrial - Arable Land",
        "Artificial/Terrestrial - Pastureland",
        "Artificial/Terrestrial - Plantations",
        "Artificial/Terrestrial - Rural Gardens",
        "Artificial/Terrestrial - Urban Areas",
        "Artificial/Terrestrial - Subtropical/Tropical Heavily Degraded Former Forest",
        "Introduced vegetation"
    )
    habitats <- c(habitats, ter_habitats)
}

for (habitat in habitats) {
  IUCN_code <- IUCN_habitats$habitats$code[IUCN_habitats$habitats$description$en == habitat]
  print(sprintf("Loading species for %s...", habitat))
  IUCN_habitat <- rredlist::rl_habitats(code = IUCN_code, key = token, latest = TRUE, scope_code = 1)$assessments

  if (nrow(IUCN_habitat) > 0) {
      IUCN_habitat$habitat <- habitat
      IUCN_habitat_splist <- rbind(IUCN_habitat_splist, IUCN_habitat)
  }
}

print(sprintf("Number of species found: %s", nrow(IUCN_habitat_splist)))

IUCN_habitat_splist$scopes <- sapply(IUCN_habitat_splist$scopes, function(x) paste(unlist(x), collapse = ", "))
IUCN_habitat_path <- file.path(outputFolder, paste0("IUCN_habitat_splist", ".csv")) # Define the file path
write.csv(IUCN_habitat_splist, IUCN_habitat_path, row.names = F) # write result

biab_output("IUCN_habitat_splist", IUCN_habitat_path)

citation <- rredlist::rl_citation(key = token)

# Extract citation
citation <- capture.output(print(citation))
lines <- trimws(unlist(strsplit(citation, "\n")))
start <- grep("^IUCN \\([0-9]{4}\\)", lines)
end <- grep("Accessed on", lines)
end <- end[end >= start][1]

citation <- paste(lines[start:end], collapse = " ")

biab_output("api_citation", citation)