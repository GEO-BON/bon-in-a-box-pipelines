packages <- c("raster", "rjson", "geojsonsf", "terra",'sf')
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
library(sf)


## get bbox from polygons of population
input <- fromJSON(file=file.path(outputFolder, "input.json"))

pop_poly <-st_read(input$population_polygons)

bbox = st_bbox(pop_poly)


## extend population polygons by 20%
dX = abs(bbox[3]-bbox[1])
dY = abs(bbox[4]-bbox[2])

bbox[1] = bbox[1]-dX*0.1
bbox[3] = bbox[3]+dX*0.1
bbox[2] = bbox[2]-dY*0.1
bbox[4] = bbox[4]+dY*0.1


# get ranges
lonRANGE = c(bbox[1],bbox[3])
latRANGE = c(bbox[2],bbox[4])


load_stac<-function(staccollection, resamplingMethod){

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
  
  out_file <- tempfile(fileext = ".tif")
  
  paths<-c()
  for (i in 1:length(lcpri_url)){
    out_file<-tempfile(pattern = paste0("tempfile_", i, "_"),fileext = ".tif")
    gdalwarp(srcfile = lcpri_url[i], 
             dstfile = out_file, 
             tr = c(res,res), 
             r = resamplingMethod)
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



print("Loading TC layers...", )
### Load and resample rasters 
res = input$res #get desired resolution from input
TC = load_stac("gfw-treecover2000", resamplingMethod  = 'average')


print("Loading TCL layers...", )
TCL0 = load_stac("gfw-lossyear", resamplingMethod = 'med') # resampling: median value, if median = 0 --> at least 50% of pixel did not loss forest 
TCL = load_stac("gfw-lossyear", resamplingMethod = 'mode') # resampling: mode while excluding 0s, find out in which year most of the pixel was lost. 


TCL[TCL0==0] = 0 # set to 0 (no loss) pixels where >50% of area did not show forest loss

## calculate year-by-year forest presence/absence
print('Calculating year-by-year forest presence/absence')
## 2000
tcyy = (TC>30)+0 # first year: TC when canopy density >30%
names(tcyy) = 'y2000'



## 2001-2023
for (y in 1:23) {
  print(paste0('y20',sprintf('%02d', y)))
  # get forest presence/absence for current year
  tcy = (tcyy[[paste0('y20',sprintf('%02d', y-1))]]==1)& # forest exist if: (1) forest was there the previous year ...
        (TCL!=y) # ...and (2) forest present did not disappeaer during current year.
  
  # add to stack
  tcyy[[paste0('y20',sprintf('%02d', y))]] = tcy+0

}

layersNames = names(tcyy)

# set NAs to 0
tcyy[is.na(tcyy)] = 0
names(tcyy) = layersNames

# subset output to years of interest
yoi = input$yoi
tcyy = tcyy[[paste0('y',as.character(yoi))]]


# write output
tcyy_p<-file.path(outputFolder, "tcyy.tif")

writeRaster(tcyy, filename = tcyy_p, filetype = "GTiff", overwrite=T)

## Outputing result to JSON
output <- list("tcyy"=tcyy_p, 'time_points'=names(tcyy)) 

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))

