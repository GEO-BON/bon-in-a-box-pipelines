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
library(raster)


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
  

#calculate tree cover absence
tree_cover_loss[TC<30]=NA
tcy=c()

# Get year-by-year tree cover for whole area
for (y in as.numeric(substr(c(yoi[1],yoi[length(yoi)]), 3,4))) {
  
  # check if there was cover in 2000 (>30%), tree cover that was never lost (==0) or cover has not been lost yet
  tci = TC>30 & (tree_cover_loss==0 | tree_cover_loss > y) 
  
  
  tcy = c(tcy, tci+0)
  
}

names(tcy)=paste0('y',c(yoi[1],yoi[length(yoi)]))

tcytot = rast(tcy)

###create cover maps for each population
# create output directory for population maps
dir.create(file.path(outputFolder, "/tcyy/"))
for (pop in pop_poly$pop) {

  print(pop)
  
  # crop rasters to pop extent
  TC_pop = crop(TC, pop_poly[pop_poly$pop==pop,], mask=T)
  tree_cover_loss_pop = crop(tree_cover_loss, pop_poly[pop_poly$pop==pop,], mask=T)
  
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
######## Resample Pixels and create three polygons describing regions where habitat was lost, increased, or remained stable
# create output directory for cover maps
dir.create(file.path(outputFolder, "/cover maps/"))
tcy<-tcytot
# calculate ∂ between habitat pop at first and last timepoint
D_tcy = tcy[[nlyr(tcy)]]-tcy[[1]]

### resample
D_tcy_canvas = D_tcy
res(D_tcy_canvas) = c(0.01,0.01)
D_tcy = resample(D_tcy, D_tcy_canvas, method='average') 

# find pixel without habitat: outside poly, or no habitat within poly
No_habitat = (tcy[[nlyr(tcy)]]==0 & tcy[[1]]==0) | is.na(tcy[[1]])

# resample information on habitat absence
no_habitat_canvas = No_habitat
res(no_habitat_canvas) = c(0.01,0.01)
No_habitat = resample(No_habitat, no_habitat_canvas, method='med') # find which resampled pixels are covered by at least 50% habitat

# remove missing habitat from delta 
D_tcy[No_habitat] = NA


## Gain/Loss if at least 10% of resampled pixel area was gained/lost
HabitatNC = (D_tcy>(-0.1)&D_tcy<(+0.1))+0;HabitatNC[HabitatNC==0]=NA
HabitatLOSS = (D_tcy<(-0.1))+0;HabitatLOSS[HabitatLOSS==0]=NA
HabitatGAIN = (D_tcy>(+0.1))+0;HabitatGAIN[HabitatGAIN==0]=NA


#write cover maps to output directory
terra::writeRaster(HabitatNC, filename = paste0(outputFolder, "/cover maps/HabitatNC.tif"), gdal=c("COMPRESS=DEFLATE", "TFW=YES"), filetype = "COG", overwrite=T)
terra::writeRaster(HabitatLOSS, filename = paste0(outputFolder, "/cover maps/HabitatLOSS.tif"), gdal=c("COMPRESS=DEFLATE", "TFW=YES"), filetype = "COG", overwrite=T)
terra::writeRaster(HabitatGAIN, filename = paste0(outputFolder, "/cover maps/HabitatGAIN.tif"), gdal=c("COMPRESS=DEFLATE", "TFW=YES"), filetype = "COG", overwrite=T)


# write output path for population maps
tcyy_p<-file.path(outputFolder, "tcyy/")
# write output path for cover maps
output_maps<-file.path(outputFolder, "cover maps/")

# Flush all remaining temporary files
unlink(paste0(normalizePath(tempdir()), "/", dir(tempdir())), recursive = TRUE)

## Outputing result to JSON
output <- list("tcyy"=tcyy_p, "output_maps"=output_maps)

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))

