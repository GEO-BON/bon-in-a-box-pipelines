#packages <- c("rjson", "geojsonsf", "terra",'sf')
#new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
#if(length(new.packages)) install.packages(new.packages)

library(rjson)
library(terra)
library(sf)


## get bbox from polygons of population
input <- fromJSON(file=file.path(outputFolder, "input.json"))

pop_poly <-st_read(input$population_polygons)

bbox = st_bbox(pop_poly)


## get years of interest
yoi = input$yoi

startY = min(as.numeric(yoi))
endY = max(as.numeric(yoi))

## load land cover data from STAC
load_stac<-function(staccollection='esacci-lc'){

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

  return(raster)
}


print("Loading Land Cover from STAC:", )
LC<-load_stac("esacci-lc")

## get landcover classes of interest
user_classes = as.numeric(input$lc_classes)

# create output director
dir.create(file.path(outputFolder, "/lcyy/"))

#### Create local raster output for every population

for (pop in pop_poly$pop) {

  print(pop)
  
  # crop rasters to pop extent
  LC_pop = crop(LC, pop_poly[pop_poly$pop==pop,], mask=T)

  LC_pop_cl = (LC_pop%in%user_classes)+0

  LC_pop_cl[is.na(LC_pop)] = NA
  
  lcy = LC_pop_cl
  
  names(lcy)=paste0('y',yoi)
  
  # write output
  terra::writeRaster(lcy, filename = paste0(outputFolder, "/lcyy/",pop,'.tif'), gdal=c("COMPRESS=DEFLATE", "TFW=YES"), filetype = "COG", overwrite=T)
  
}


# write output
lcyy_p<-file.path(outputFolder, "lcyy/")

# Flush all remaining temporary files
unlink(paste0(normalizePath(tempdir()), "/", dir(tempdir())), recursive = TRUE)


## Outputing result to JSON
output <- list("lcyy"=lcyy_p)

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))

