if (!require(ohicore)){devtools::install_github('ohi-science/ohicore')}
library(ohicore)
library(tidyverse)
library(plotly)
library(zoo)
library(htmlwidgets)
library(here)

input <- biab_inputs()

## Choose years for assessment
# This needs to align with the scenario_data_years.csv file
scenario_years <- c(input$start_year:input$end_year)

# Identify path to OHI data prep repository
#repo_path_prep <- paste0("https://raw.githubusercontent.com/OHI-Science/ohiprep_v", input$end_year, "/refs/heads/main/globalprep")

repo_path <- "https://raw.githubusercontent.com/OHI-Science/ohi-global/draft"

## Read in the layers.csv file with paths to the data files
g <- read.csv(file.path(repo_path, "eez", "layers.csv"), stringsAsFactors = FALSE, na.strings='')
print(g)
# Load layers EEZ script
path_script <- Sys.getenv("SCRIPT_LOCATION")

# Update layers with the latest updates (skip for now)
#source(file.path(path_script, "ohi/layers_eez_script.R"), echo = TRUE)

## establish locations of layers and save information (skip for now and just pull the layers directly from the OHI global repository)
# lyrs = g %>%
#   dplyr::filter(ingest==TRUE) %>%
#   dplyr::mutate(dir = gsub("ohiprep:", repo_path_prep, dir)) %>%
#   dplyr::mutate(
#     path_in        = file.path(dir, fn),
#     #path_in_exists = file.exists(path_in),
#     filename = sprintf('%s.csv', layer),
#     path_out = sprintf(here('eez/layers/%s.csv'), layer)) %>%
#   dplyr::select(
#     targets, layer, name, description,
#     fld_value=name_data_fld, units,
#     path_in, filename, path_out, ingest) %>%  # path_in_exists
#   dplyr::arrange(targets, layer)

# # copy layers into layers folder
# for (j in 1:nrow(lyrs)){ # j=4
#   tmp <- read.csv(lyrs$path_in[j])
#   write.csv(tmp, lyrs$path_out[j], row.names=FALSE)
# }

# delete extraneous files
# files_extra = setdiff(list.files('layers'), as.character(lyrs$filename))
# unlink(sprintf('layers/%s', files_extra))

# layers registry (this includes files that are ingest=FALSE)
# lyrs_reg = lyrs %>%
#   dplyr::select(
#     targets, ingest, layer, name, description,
#     fld_value, units, filename)

# layers_path <- file.path(outputFolder, "layers.csv")
# write.csv(lyrs_reg, layers_path, na = '', row.names = FALSE, na='')
# biab_output("layers", layers_path)

# Run check on layers
conf = ohicore::Conf(file.path("/userdata", "conf"))

print(file.exists("/userdata/layers.csv"))
print(file.exists("/userdata/layers"))
print(file.exists("/userdata/layers/"))

# This isn't really working right now
# ohicore::CheckLayers(layers.csv = file.path("/userdata", "layers.csv"),
#             layers.dir = file.path("/userdata", "layers/"),
#             flds_id    = conf$config$layers_id_fields)


## General function to calculate scores
get_scores <- function(s_year){  #s_year=2020

  #s_year <- as.numeric(s_year)
  print(sprintf("For assessment year %s", s_year))

  # set the scenario year
  layers$data$scenario_year <-  s_year

  # clear out the file that keeps track of reference points for each scenario year

 # if(file.exists(sprintf(file.path(repo_path, "eez", "temp", "reference_pts_%s.csv"), s_year)))
  #{file.remove(sprintf(file.path(repo_path, "eez", "temp", "reference_pts_%s.csv"), s_year))}

  ref_pts <- data.frame(year   = as.integer(),
                        goal   = as.character(),
                        method = as.character(),
                        reference_point = as.character())
#  write_csv(ref_pts, sprintf(here('eez/temp/reference_pts_%s.csv'), s_year))


  # calculate scores
  scores_sy <- ohicore::CalculateAll(conf, layers) %>%
    dplyr::mutate(year = s_year)

}

## Apply function
### set up conf and layer objects
conf   <-  ohicore::Conf(file.path("/userdata", "conf"))
layers <-  ohicore::Layers(layers.csv = file.path("/userdata", "layers.csv"), layers.dir = file.path("/userdata", "layers"))

#scorelist = lapply(X=2018, FUN=get_scores)
scorelist = lapply(X = scenario_years, FUN = get_scores)
scores_all_years <- dplyr::bind_rows(scorelist)


# save results
scores_path <- file.path(outputFolder, "scores.csv")
write.csv(scores_all_years, scores_path, na = '', row.names = FALSE)

biab_output("scores", scores_path)