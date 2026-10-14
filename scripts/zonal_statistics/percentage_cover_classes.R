library(rjson)
library(sf)
library(dplyr)
library(terra)
library(exactextractr)

input <- biab_inputs()
# load rasters
rasters <- rast(input$rasters)
study_area <- st_read(input$study_area)

# Get proportions per polygon
# proportions <- exact_extract(rasters, study_area, function(values, coverage_fractions) {
#   # Sum coverage for each category
#   prop.table(tapply(coverage_fractions, values, sum, na.rm = TRUE))
# })
print(summary(rasters))

freq_table <- freq(rasters)
print(head(freq_table))

# Calculate proportions
freq_table$proportion <- freq_table$count / sum(freq_table$count)

freq_table$proportion <- freq_table$count / sum(freq_table$count)

cell_area <- prod(res(rasters)) # area of rasters
freq_table$area_km2 <- (freq_table$count * cell_area)/1000000

# temporary fix
#freq_table$layer <- names(rasters)

#freq_table <- freq_table[,c(6,3,4,5)]

category_path <- file.path(outputFolder, "class_percentage.csv")
write.csv(freq_table, category_path)
biab_output("class_percentage", category_path)