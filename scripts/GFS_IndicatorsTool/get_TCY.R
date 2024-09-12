packages <- c("raster", "rjson", "geojsonsf", "terra",'sf')
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

library(raster)
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


load_stac<-function(staccollection){

  stac_query <- rstac::stac(
    "https://stac.geobon.org/"
  ) |>
    rstac::stac_search(
      collections = staccollection,
      bbox = bbox,
      limit = 100
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

  
  # open rasters from server
  raster = crop(rast(lcpri_url[1]), bbox[c(1,3,2,4)]) # crop
  
  if (length(lcpri_url)>1) {
  
  for (i in 2:length(lcpri_url)) {
    
    print(i/length(lcpri_url))
    raster_server = rast(lcpri_url[i])
    raster_i = crop(rast(lcpri_url[1]), bbox[c(1,3,2,4)]) # crop

    # add to final raster
    raster = mosaic(raster, raster_i)
  
  }

  }
  return(raster)
  }
 
print("Loading TC layers...", )

 
TCnative = load_stac("gfw-treecover2000")
TCLnative = load_stac("gfw-lossyear")

### Resample rasters 
print("resampling layers...")

#get desired resolution from input
res = input$res

TC = terra::resample(TCnative, rast(res=c(res,res), ext=ext(TCnative)), method='average') # resampling: get average canopy cover in 2000 per pixel
TCL0 = terra::resample(TCLnative, rast(res=c(res,res), ext=ext(TCLnative)), method='med') # resampling: median value, if median = 0 --> at least 50% of pixel did not loss forest 
TCL = terra::resample(TCLnative, rast(res=c(res,res), ext=ext(TCLnative)), method='mode') # resampling: mode while excluding 0s, find out in which year most of the pixel was lost. 


TCL[TCL0==0] = 0 # set to 0 (no loss) pixels where >50% of area did not show forest loss


## calculate year-by-year forest presence/absence
print('Calculating year-by-year forest presence/absence')
## 2000
TCY = (TC>30)+0 # first year: TC when canopy density >30%
names(TCY) = 'y2000'



## 2001-2023
for (y in 1:23) {
  print(paste0('y20',sprintf('%02d', y)))
  # get forest presence/absence for current year
  tcy = (TCY[[paste0('y20',sprintf('%02d', y-1))]]==1)& # forest exist if: (1) forest was there the previous year ...
        (TCL!=y) # ...and (2) forest present did not disappeaer during current year.
  
  # add to stack
  TCY[[paste0('y20',sprintf('%02d', y))]] = tcy+0

}

# set NAs to 0
TCY[is.na(TCY)] = 0

# subset output to years of interest
YOI = input$YOI

TCY = TCY[[paste0('y',as.character(YOI))]]



# write output
TCY_p<-file.path(outputFolder, "TCY.tif")

writeRaster(TCY, filename = TCY_p, filetype = "GTiff", overwrite=T)

## Outputing result to JSON
output <- list("TCY"=TCY_p, 'time.points'=names(TCY)) 

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))

