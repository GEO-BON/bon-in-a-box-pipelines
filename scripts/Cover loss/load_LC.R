
packages <- c("raster", "rjson", "geojsonsf", "terra")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)
if(!"rgdal"%in% installed.packages()){
  install.packages("rgdal", repos="http://R-Forge.R-project.org", type="source")
}
if(!"gdalUtils"%in% installed.packages()){
  library(devtools)
  devtools::install_github("gearslaboratory/gdalUtils")
}
library(raster)
library(gdalUtils)
library(rjson)
library(terra)

input <- fromJSON(file=file.path(outputFolder, "input.json"))

bbox<-input$bbox
lonRANGE = c(bbox[1],bbox[3])
latRANGE = c(bbox[2],bbox[4])

for(i in c(1,2)){
  if (bbox[i] %% 10 == 0) {
    bbox[i] <- bbox[i] + 0.1
  }
}
for(i in c(3,4)){
  if (bbox[i] %% 10 == 0) {
    bbox[i] <- bbox[i] - 0.1
  }
}

load_stac<-function(staccollection){
  stac_query <- rstac::stac(
    "https://stac.geobon.org/"
  ) |>
    rstac::stac_search(
      collections = staccollection,
      bbox = bbox,
    ) |>
    rstac::get_request()

  make_vsicurl_url <- function(base_url) {
    paste0(
      "/vsicurl",
      "?pc_url_signing=no",
      paste0("&pc_collection=",staccollection),
      "&url=",
      base_url
    )
  }

  lcpri_url <- make_vsicurl_url(rstac::assets_url(stac_query, "data"))
  lcpri_url

  out_file <- tempfile(fileext = ".tif")

  paths<-c()
  for (i in 1:length(lcpri_url)){
    out_file<-tempfile(pattern = paste0("tempfile_", i, "_"),fileext = ".tif")
    gdalwarp(srcfile = lcpri_url[i],
             dstfile = out_file,
             tr = c(0.001, 0.001),
             r = "average")
    paths[i]<-out_file
  }
  rasters <- lapply(paths, raster)
  for (i in 1:length(rasters)){
    rasters[[i]]<-crop(rasters[[i]], c(lonRANGE,latRANGE))
  }
  if(length(rasters)>1){
    rasters <- do.call(terra::mosaic, c(rasters, list(fun = "mean")))
  }
  else(rasters<-rasters[[1]])
  return(rasters)
}
print("Loading TC:")
TC<-load_stac("gfw-treecover2000")
print("Loading tree_cover_loss:")
tree_cover_loss<-load_stac("gfw-lossyear")

tree_cover_loss_p<-file.path(outputFolder, "tree_cover_loss.tif")
TC_p<-file.path(outputFolder, "TC.tif")


writeRaster(tree_cover_loss[[1]], tree_cover_loss_p, format = "GTiff")
writeRaster(TC[[1]], TC_p, format = "GTiff")

## Outputing result to JSON
output <- list("tree_cover_loss"=tree_cover_loss_p, "TC"=TC_p)

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))
