if (!require(devtools)){install.packages("devtools")}
if (!require(ohicore)){devtools::install_github('ohi-science/ohicore@master')}
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

# Identify path to OHI data repository
version_year <- paste0("v", input$end_year)
repo_loc <- paste0("https://raw.githubusercontent.com/OHI-Science/ohiprep_", version_year, "/refs/heads/main/")

## Read in the layers.csv file with paths to the data files
g <- read.csv(here("eez/layers.csv"), stringsAsFactors = FALSE, na.strings='')

# Load layers EEZ script 
source(here("metadata_documentation", "layers_eez_script.R"))

## Read in the layers.csv file with paths to the data files
g <- read.csv(here("eez/layers.csv"), stringsAsFactors = FALSE, na.strings='')

## establish locations of layers and save information
lyrs = g %>%
  dplyr::filter(ingest==TRUE) %>%
  dplyr::mutate(dir = gsub("ohiprep:", repo_loc, dir)) %>%
  dplyr::mutate(
    path_in        = file.path(dir, fn),
    #path_in_exists = file.exists(path_in),
    filename = sprintf('%s.csv', layer),
    path_out = sprintf(here('eez/layers/%s.csv'), layer)) %>%
  dplyr::select(
    targets, layer, name, description,
    fld_value=name_data_fld, units,
    path_in, filename, path_out, ingest) %>%  # path_in_exists
  dplyr::arrange(targets, layer)

# copy layers into layers folder
for (j in 1:nrow(lyrs)){ # j=4
  tmp <- read.csv(lyrs$path_in[j])
  write.csv(tmp, lyrs$path_out[j], row.names=FALSE)
}

# delete extraneous files
files_extra = setdiff(list.files('layers'), as.character(lyrs$filename))
unlink(sprintf('layers/%s', files_extra))

# layers registry (this includes files that are ingest=FALSE)
lyrs_reg = lyrs %>%
  dplyr::select(
    targets, ingest, layer, name, description,
    fld_value, units, filename)

write.csv(lyrs_reg, here('eez/layers.csv'), row.names=F, na='')

# Run check on layers
conf = ohicore::Conf(here('eez/conf'))

ohicore::CheckLayers(layers.csv = here('eez/layers.csv'),
            layers.dir = here('eez/layers'),
            flds_id    = conf$config$layers_id_fields)


## General function to calculate scores
get_scores <- function(s_year){  #s_year=2020

  #s_year <- as.numeric(s_year)
  print(sprintf("For assessment year %s", s_year))

  # set the scenario year
  layers$data$scenario_year <-  s_year

  # clear out the file that keeps track of reference points for each scenario year

  if(file.exists(sprintf(here('eez/temp/reference_pts_%s.csv'), s_year)))
  {file.remove(sprintf(here('eez/temp/reference_pts_%s.csv'), s_year))}

  ref_pts <- data.frame(year   = as.integer(),
                        goal   = as.character(),
                        method = as.character(),
                        reference_point = as.character())
  write_csv(ref_pts, sprintf(here('eez/temp/reference_pts_%s.csv'), s_year))


  # calculate scores
  scores_sy <- ohicore::CalculateAll(conf, layers) %>%
    dplyr::mutate(year = s_year)

}

## Apply function
### set up conf and layer objects
conf   <-  ohicore::Conf(here('eez/conf'))
layers <-  ohicore::Layers(layers.csv = here('eez/layers.csv'), layers.dir = here('eez/layers'))

#scorelist = lapply(X=2018, FUN=get_scores)
scorelist = lapply(X = scenario_years, FUN = get_scores) # 28 warnings were generated (nothing of concern)
scores_all_years <- dplyr::bind_rows(scorelist)


# save results
scores_path <- file.path(outputFolder, "scores.csv")
write.csv(scores_all_years, scores_path, na = '', row.names = FALSE)

biab_output("scores", scores_path)