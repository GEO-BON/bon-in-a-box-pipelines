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

##Check if Inputs correct
if (min(input$yoi)<1992 | max(input$yoi>2020)){
  stop("\n*********************************************\n",
       "*** ERROR: YEARS OF INTEREST OUT OF BOUND ***\n",
       "*********************************************\n",
       "Error Message: Years of interest out of bound. Must be between 1992 and 2020.\n\n")
}

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
lcy = LC
lcy = (LC%in%user_classes)+0

lcy[is.na(LC)] = NA

names(lcy)=paste0('y',yoi)
### Resample Pixels and create three polygons describing regions where habitat was lost, increased, or remained stable
# create output directory for cover maps
dir.create(file.path(outputFolder, "cover maps/"))

# calculate ∂ between habitat pop at first and last timepoint
D_lcy = lcy[[nlyr(lcy)]]-lcy[[1]]

### resample
D_lcy_canvas = D_lcy
res(D_lcy_canvas) = c(0.01,0.01)
D_lcy = resample(D_lcy, D_lcy_canvas, method='average') 

# find pixel without habitat: outside poly, or no habitat within poly
No_habitat = (lcy[[nlyr(lcy)]]==0 & lcy[[1]]==0) | is.na(lcy[[1]])

# resample information on habitat absence
no_habitat_canvas = No_habitat
res(no_habitat_canvas) = c(0.01,0.01)
No_habitat = resample(No_habitat, no_habitat_canvas, method='med') # find which resampled pixels are covered by at least 50% habitat

# remove missing habitat from delta 
D_lcy[No_habitat] = NA


## Gain/Loss if at least 10% of resampled pixel area was gained/lost
HabitatNC = (D_lcy>(-0.1)&D_lcy<(+0.1))+0;HabitatNC[HabitatNC==0]=NA
HabitatLOSS = (D_lcy<(-0.1))+0;HabitatLOSS[HabitatLOSS==0]=NA
HabitatGAIN = (D_lcy>(+0.1))+0;HabitatGAIN[HabitatGAIN==0]=NA


#write cover maps to output directory
terra::writeRaster(HabitatNC, filename = paste0(outputFolder, "/cover maps/HabitatNC.tif"), gdal=c("COMPRESS=DEFLATE", "TFW=YES"), filetype = "COG", overwrite=T)
terra::writeRaster(HabitatLOSS, filename = paste0(outputFolder, "/cover maps/HabitatLOSS.tif"), gdal=c("COMPRESS=DEFLATE", "TFW=YES"), filetype = "COG", overwrite=T)
terra::writeRaster(HabitatGAIN, filename = paste0(outputFolder, "/cover maps/HabitatGAIN.tif"), gdal=c("COMPRESS=DEFLATE", "TFW=YES"), filetype = "COG", overwrite=T)



# write output
lcyy_p<-file.path(outputFolder, "lcyy/")
output_maps<-file.path(outputFolder, "cover maps/")

# Flush all remaining temporary files
unlink(paste0(normalizePath(tempdir()), "/", dir(tempdir())), recursive = TRUE)


## Outputing result to JSON
output <- list("lcyy"=lcyy_p, "output_maps"=output_maps)

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))

