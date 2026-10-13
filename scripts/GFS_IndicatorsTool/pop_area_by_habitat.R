library(rjson)
library(terra)
library(sf)

input <- fromJSON(file=file.path(outputFolder, "input.json"))

cropland  <- c(10, 11, 12, 20)
forest    <- c(50, 60, 61, 62, 70, 71, 72, 80, 81, 82, 90, 160, 170)
grassland <- c(130)
shrubland <- c(120, 121, 122)

lc_classes <- input$lc_classes
is_tree_cover <- identical(lc_classes, "TC")   # binary tree cover map, no land cover codes

if (!is_tree_cover) {
  lc_classes <- as.numeric(lc_classes)
}

## load population polygons and habitat cover map
pop_poly  <- st_read(input$population_polygons)
habitat_p <- input$habitat_map

## Polygon areas (km2), only needed for the tree cover method
if (is_tree_cover) {
  print("Calculating as Treecover method")
  sf_use_s2(F)
  POP_AREA <- as.numeric(st_area(pop_poly)) / 1000000
  names(POP_AREA) <- pop_poly$name
}

POP_HABITAT_AREA <- c()

for (name in pop_poly$name) {
  print(name)
  habitat <- rast(paste0(habitat_p, name, '.tif'))

  if (is_tree_cover) {
    ## Old way: mean of binary raster (cover fraction) * polygon area
    pop_habitat <- unlist(lapply(habitat, function(x) mean(x[], na.rm = TRUE)))
    total <- round(pop_habitat * POP_AREA[name], 2)

  } else {
    ## Land-cover-class way
    total <- sapply(habitat, function(x) {
      global(cellSize(x, unit = "km") * (x %in% lc_classes), "sum", na.rm = TRUE)[1, 1]
    })
    crop       <- sapply(habitat, function(x) global(cellSize(x, unit = "km") * (x == 30),  "sum", na.rm = TRUE)[1, 1])
    natural    <- sapply(habitat, function(x) global(cellSize(x, unit = "km") * (x == 40),  "sum", na.rm = TRUE)[1, 1])
    tree       <- sapply(habitat, function(x) global(cellSize(x, unit = "km") * (x == 100), "sum", na.rm = TRUE)[1, 1])
    herbaceous <- sapply(habitat, function(x) global(cellSize(x, unit = "km") * (x == 110), "sum", na.rm = TRUE)[1, 1])

    if (any(lc_classes %in% cropland)) {
      total <- total + crop*0.66 + natural*0.33
      print("cropland added")
    }
    if (any(lc_classes %in% forest) | any(lc_classes %in% shrubland)) {
      total <- total + tree*0.66 + herbaceous*0.33
      print("forest added")
    }
    if (any(lc_classes %in% grassland)) {
      total <- total + tree*0.33 + herbaceous*0.66
      print("grass added")
    }
    if (any(lc_classes %in% grassland) | any(lc_classes %in% forest) | any(lc_classes %in% shrubland)) {
      total <- total + natural*0.66 + crop*0.33
      print("grass and forest added")
    }
    total <- round(total, 2)
  }

  names(total) <- names(habitat)
  POP_HABITAT_AREA <- rbind(POP_HABITAT_AREA, c('name' = name, total))
}

print(POP_HABITAT_AREA)

## Write output
path <- file.path(outputFolder, "pop_habitat_area.tsv")
write.table(POP_HABITAT_AREA, path,
            append = F, row.names = F, col.names = T, sep = "\t", quote = F)

output <- list("pop_area" = path)
write(toJSON(output, indent = 2), file.path(outputFolder, "output.json"))