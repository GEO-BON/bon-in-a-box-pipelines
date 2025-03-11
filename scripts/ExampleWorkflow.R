# Script to pull observations from OBIS (Ocean Biodiversity Information System) and seascape data and plot some metrics
# with seascape data

###################################
# PRACTICE SCRIPT

#remotes::install_github("marinebon/seascapeR") 
# more info here (https://marinebon.github.io/seascapeR/reference/index.html)

library(seascapeR) # for pulling info about ocean
library(robis) # for pulling OBIS data
library(terra)
library(sf)
library(tidyverse)

# First, we will load data from seascapeR, which contains seascape classes, which can be found here 
# (https://coastwatch.noaa.gov/cwn/products/seascape-pelagic-habitat-classification.html)

# Get info for seascape data
ss_info <- get_ss_info("global_monthly") # or global_8day (user can choose)

# Choose variable (want habitat class)
ss_var <- "CLASS"  

# You can make a polygon using a bounding box 
custom_ply <- bbox_ply(-127, 5, -122, 8) # user can choose

# potentially include option to upload your own polygon
#custom_ply <- st_read("some_polygon.shp")

# Get seascape data for the polygon selected
ss_grids <- get_ss_grds(ss_info, custom_ply, ss_var, date_beg=max(get_ss_dates(ss_info)), 
                        date_end=max(get_ss_dates(ss_info))) 

plot(ss_grids)

# Extract percentage of each polygon covered by each class
freq_table <- as.data.frame(freq(ss_grids))

# Total number of cells in the raster
total_cells <- ncell(ss_grids)

# Calculate the percentage of the bounding box that is each habitat category
freq_table$percentage_landcover <- (freq_table$count / total_cells) * 100

# Print the summary
print(freq_table)

#### Plot percentage of area with each habitat
# Merge with classification CSV (from: https://coastwatch.noaa.gov/cwn/products/seascape-pelagic-habitat-classification.html)
classifications <- read.csv("userdata/seascapes_classification.csv")
percent_class <- merge(classifications, freq_table, by.x="seascape_id_number", by.y="value")

#Plot percentages of each class in the polygon
ggplot(percent_class)+
  geom_col(mapping=aes(x=nominal_descriptor, y=percentage_landcover, fill=nominal_descriptor), position="dodge")+
  coord_flip()+
  labs(title="Seascape class percentage", y= "Percentage landcover")+
  theme_classic()+
  theme(axis.title.y=element_blank(), legend.position="none")

#### Pull data for species of interest and plot percentage of points in each class for each species

#### Pull OBIS data
polygon_wkt <- st_as_text(custom_ply)

species <- c("Stenella coeruleoalba","Astronesthes cyaneus")# user can choose one or more species

dat <- occurrence(scientificname = species, geometry=polygon_wkt)
# Some species to play around with
#Stenella coeruleoalba
#Astronesthes cyaneus
#Notolychnus valdiviae
#Pterotrachea hippocampus

ggplot()+
  geom_point(dat, mapping=aes(decimalLatitude, decimalLongitude, color=species))
  
# extract seascape values for each occurrence point
dat$seascape_class <- terra::extract(ss_grids, dat[,c("decimalLongitude", "decimalLatitude")])

# Plot percentage of occurrences that are in each class and percentage of total 
dat_summary <- dat %>% group_by(species) %>% 
  mutate(total_occ=n()) %>% group_by(species, seascape_class, total_occ) %>% 
  summarise(total=n()) %>% mutate(percentage_species=(total/total_occ*100))


# Merge with seascape categories
dat_summary_merged <- merge(classifications, dat_summary, by.x="seascape_id_number", by.y="seascape_class")


ggplot(dat_summary_merged)+
  geom_col(dat_summary_merged, mapping=aes(y=percentage_species, x=nominal_descriptor, fill=nominal_descriptor))+
  coord_flip()+
  facet_wrap(~species)+
  labs(y= "Percentage of occurences in class")+
  theme_classic()+
  theme(axis.title.y=element_blank(), legend.position="none")

dat_summary_merged$percentage_species


