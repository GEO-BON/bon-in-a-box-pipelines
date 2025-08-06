# layer of start year
# layer of end year
# habitat type text[]
# raster of area of habitat

# step1: pull cells only of that habitat type
# step2: crop by area of habitat

input <- biab_inputs()

layers <- terra::rast(c(input$layers))
print("Rasters:")
print(layers)
habitats <- input$habitats
aoh <- terra::rast(input$aoh)

# Step 1: Filter habitat types per layer
filtered_layers <- lapp(layers, fun = function(x) {
  ifelse(x %in% habitats, x, NA)  # Keep only matching habitat types
})

# Step 2: Mask each filtered layer by AOH
masked_by_aoh <- mask(filtered_layers, aoh)
