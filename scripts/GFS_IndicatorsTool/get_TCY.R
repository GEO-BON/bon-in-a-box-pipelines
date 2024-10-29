#packages <- c("rjson", "geojsonsf", "terra",'sf')
#new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
#if(length(new.packages)) install.packages(new.packages)
#if(!"rgdal"%in% installed.packages()){
# install.packages("rgdal", repos="http://R-Forge.R-project.org", type="source")
#}
#if(!"gdalUtils"%in% installed.packages()){
#  library(devtools)
#  devtools::install_github("gearslaboratory/gdalUtils")
#}

library(gdalUtils)
library(rjson)
library(terra)
library(sf)


## get bbox from polygons of population
input <- fromJSON(file=file.path(outputFolder, "input.json"))

pop_poly <-st_read(input$population_polygons)

bbox = st_bbox(pop_poly)


### function to download raster tiles from stac
load_stac<-function(staccollection){

  stac_query <- rstac::stac(
    "https://stac.geobon.org/"
  ) |>
    rstac::stac_search(
      collections = staccollection,
      bbox = bbox,
      limit=50
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
  
  ### Get rasters from stac
  out_file<-tempfile(pattern = paste0("tempfile"),fileext = ".tif")
  
  gdalwarp(srcfile = lcpri_url, 
           dstfile = out_file, 
           options = c("COMPRESS=DEFLATE", "TILED=YES"),
           te = bbox
           )
  
  ### return path to temporary files
  return(out_file)
}



### Load and resample rasters

print("Loading GFW Tree Cover layer...", )
treecover2000 = load_stac("gfw-treecover2000") # get tiles
TC = rast(treecover2000) # create raster

print("Loading GFW Tree Cover year loss layer...", )
lossyear = load_stac("gfw-lossyear") # get tiles
tree_cover_loss = rast(lossyear) # create raster



## calculate year-by-year forest presence/absence
print('Calculating year-by-year forest presence/absence')

# subset output to years of interest
yoi = input$yoi

# create output director
dir.create(file.path(outputFolder, "/tcyy/"))


#### Create local raster output for every population

for (pop in pop_poly$pop) {

  print(pop)
  
  # crop rasters to pop extent
  TC_pop = crop(TC, pop_poly[pop_poly$pop==pop,], mask=T)
  tree_cover_loss_pop = crop(tree_cover_loss, pop_poly[pop_poly$pop==pop,], mask=T)
  
  tree_cover_loss_pop[TC_pop<30] = NA
  
  
  
  # container of rasters
  tcy=c()
  
  # Get year-by-year tree cover
  for (y in as.numeric(substr(yoi, 3,4))) {
    
      # check if there was cover in 2000 (>30%), tree cover that was never lost (==0) or cover has not been lost yet
      tci = TC_pop>30 & (tree_cover_loss_pop==0 | tree_cover_loss_pop > y) 

    
    tcy = c(tcy, tci+0)
    
  }
  
  names(tcy)=paste0('y',yoi)
  
  tcy = rast(tcy)

  # write output
  terra::writeRaster(tcy, filename = paste0(outputFolder, "/tcyy/",pop,'.tif'), gdal=c("COMPRESS=DEFLATE", "TFW=YES"), filetype = "COG", overwrite=T)
  
}


# write output
tcyy_p<-file.path(outputFolder, "tcyy/")

# Flush all remaining temporary files
unlink(paste0(normalizePath(tempdir()), "/", dir(tempdir())), recursive = TRUE)

## Outputing result to JSON
output <- list("tcyy"=tcyy_p)

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))

