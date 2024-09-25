#packages <- c("raster", "rjson", "geojsonsf", "terra",'sf')
#new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
#if(length(new.packages)) install.packages(new.packages)

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

## get desired resolution from input
res = input$res

## get years of interest
yoi = input$yoi

startY = min(as.numeric(yoi))
endY = max(as.numeric(yoi))

## load land cover data from STAC
load_stac<-function(staccollection='esacci-lc', resamplingMethod='mode', noData=NULL){

  stac_query <- rstac::stac(
    "https://stac.geobon.org/"
  ) |>
    rstac::stac_search(
      collections = staccollection,
      datetime = paste0(startY,"-01-01T00:00:00Z/",endY,"-12-31T23:59:59Z"),
      limit = 50
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

  # get download URLs
  lcpri_url <- make_vsicurl_url(rstac::assets_url(stac_query, paste0('esacci-lc-',yoi)))
  lcpri_url


  # open rasters from server
  raster_server = rast(lcpri_url)

  # process rasters from server (crop to study area , reasample)
  raster = crop(raster_server, bbox[c(1,3,2,4)]) # crop
  raster = resample(raster, rast(res=c(res,res), extent=(raster)), method = resamplingMethod) # resample

  return(raster)
}


print("Loading Land Cover from STAC:", )
LC<-load_stac("esacci-lc", resamplingMethod = 'mode')


## get landcover classes of interest
user_classes = as.numeric(input$lc_classes)


# subset landcover map to classes of interst
LC_bin = LC%in%user_classes+0
names(LC_bin) = paste0('y',yoi)


# write output
lcyy_p<-file.path(outputFolder, "lcyy.tif")
writeRaster(LC_bin, filename = lcyy_p, gdal=c("COMPRESS=DEFLATE", "TFW=YES"), filetype = "COG", overwrite=T)


## Outputing result to JSON
output <- list("lcyy"=lcyy_p, 'time_points'=names(LC_bin))

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))

