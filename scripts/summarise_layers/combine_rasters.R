# this script combines two sets of rasters into a single set of rasters.

inputs <- biab_inputs()

rasters1 <- inputs$rasters1
rasters2 <- inputs$rasters2

combined_rasters <- c(rasters1, rasters2)

biab_output("combined_rasters", combined_rasters)
