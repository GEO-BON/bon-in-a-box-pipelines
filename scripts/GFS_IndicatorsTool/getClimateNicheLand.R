#### Load packages

packages <- c("dismo", "ecmwfr", "elevatr", "terra", "raster", "foreach", "doParallel", "sf")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

library(dismo) # for maxent
library(ecmwfr) # to get climate data
library(elevatr) # to get altitude data
library(terra)
library(raster)
library(foreach)
library(doParallel)
library(sf)



### User input
input <- fromJSON(file=file.path(outputFolder, "input.json"))

pop_poly <-st_read(input$pop_poly) # POPULATION POLYGONS

staY_obs = input$start_year  # starting year of species observation
endY_obs = input$end_year  # ending year species observation 

yoi = input$yoi # years of interest for habitat change

### Server settings

### set API token for ecmwfr
APIuserID <- Sys.getenv("API_USER_ID")
APIkey <- Sys.getenv("API_KEY")

#######
####### Calculate spatial and temporal window of interest
#######


### Calculate bbox study area
bbox = st_bbox(pop_poly)


### Calculate length of temporal window used to get observations 
years_span = endY_obs-staY_obs


### Calculate temporal range to get environmental variables
minY = staY_obs
maxY = max(yoi)




############
############  Get climate data 
############
print(packageVersion('ecmwfr') )
options(keyring_backend = "file")
wf_set_key(user = APIuserID, key = APIkey)

### set name of temporary variables
tmp_files = c('total_precipitation' = tempfile(tmpdir = '.', fileext = '.grib'),
              '2m_temperature' = tempfile(tmpdir = '.', fileext = '.grib'),
              'potential_evaporation' = tempfile(tmpdir = '.', fileext = '.grib'), 
              'snow_cover' = tempfile(tmpdir = '.', fileext = '.grib'))

### Get raw ERA5 data (might take a few minutes)
for (evar in names(tmp_files)) {
  
  print(paste0('Dowloading ',evar,'...'))

    req =  list(
    product_type = "reanalysis",
    dataset_short_name = "reanalysis-era5-land-monthly-means",
    variable = evar,
    year = minY:maxY,
    month = sprintf('%02d', 1:12),
    area = bbox[c(4,1,2,3)],
    target =  tmp_files[evar])
  
    wf_request(request= req,transfer = T , user = APIuserID, path = tmpDir(), verbose = F)
  
}

### load dowloaded raw variables in R
PREC = rast(paste0(tmpDir(),tmp_files['total_precipitation']))
TEMP = rast(paste0(tmpDir(),tmp_files['2m_temperature']))
EVAP = rast(paste0(tmpDir(),tmp_files['potential_evaporation']))
SNOW = rast(paste0(tmpDir(),tmp_files['snow_cover']))

# set layers identifiers as month & year of measurment
names(PREC)=names(TEMP)=names(EVAP)=names(SNOW)=substr(time(PREC),1,7)

### Create index of years
yrs = substr(names(PREC), 1, 4)


############
############  Get topographic  data 
############


## load land cover data from STAC
stac_query <- rstac::stac(
  "https://stac.geobon.org/"
) |>
  rstac::stac_search(
    collections = 'earthenv_topography',
    limit = 50
  ) |>
  rstac::get_request()

make_vsicurl_url <- function(base_url) {
  paste0(
    "/vsicurl",
    "?pc_url_signing=no",
    paste0("&pc_collection=", 'earthenv_topography'),
    "&url=",
    base_url
  )
}

# get download URLs
lcpri_url <- make_vsicurl_url(rstac::assets_url(stac_query, paste0('data')))


# get topographic variables for study area
TOPO = crop(rast(lcpri_url), bbox[c(1,3,2,4)]) # crop

# resample to match climatic data resolution and extent
TOPO = resample(TOPO, PREC)



############
############ Get landcover data
############

## load land cover data from STAC
stac_query <- rstac::stac(
    "https://stac.geobon.org/"
  ) |>
    rstac::stac_search(
      collections = 'earthenv_landcover',
      limit = 50
    ) |>
    rstac::get_request()
  
  
make_vsicurl_url <- function(base_url) {
    paste0(
      "/vsicurl",
      "?pc_url_signing=no",
      paste0("&pc_collection=", 'earthenv_landcover'),
      "&url=",
      base_url
    )
  }
  
# get download URLs
lcpri_url <- make_vsicurl_url(rstac::assets_url(stac_query, paste0('data')))

  

# get landcover classification for study area
LACO = crop(rast(lcpri_url), bbox[c(1,3,2,4)]) # crop

# resample to match climatic data resolution and extent
LACO = resample(LACO, PREC)




############
############  Calculate bioclimatic variables for the observational period
############


### Create set of variables for model training

##### mean temperature
BIOCLIM = app(TEMP[[which(yrs%in%staY_obs:endY_obs)]]-273.15, mean)
names(BIOCLIM)[nlyr(BIOCLIM)] = 'temp_mean'

##### std temperature
BIOCLIM = c(BIOCLIM, app(TEMP[[which(yrs%in%staY_obs:endY_obs)]], sd))
names(BIOCLIM)[nlyr(BIOCLIM)] = 'temp_std'

##### max temperature
BIOCLIM = c(BIOCLIM, app(TEMP[[which(yrs%in%staY_obs:endY_obs)]]-273.15, max))
names(BIOCLIM)[nlyr(BIOCLIM)] = 'temp_max'

### min temperature
BIOCLIM = c(BIOCLIM, app(TEMP[[which(yrs%in%staY_obs:endY_obs)]]-273.15, min))
names(BIOCLIM)[nlyr(BIOCLIM)] = 'temp_min'


### nb months with negative mean temperature
BIOCLIM = c(BIOCLIM, app(TEMP[[which(yrs%in%staY_obs:endY_obs)]]-273.15, function(x) {mean((x)<0)}))
names(BIOCLIM)[nlyr(BIOCLIM)] = 'temp_com'


### nb months with growing season  temperature (>5°)
BIOCLIM = c(BIOCLIM, app(TEMP[[which(yrs%in%staY_obs:endY_obs)]]-273.15, function(x) {mean((x)>5)}))
names(BIOCLIM)[nlyr(BIOCLIM)] = 'temp_gsm'


### nb months with growing season  temperature (>5°)
BIOCLIM = c(BIOCLIM, app(TEMP[[which(yrs%in%staY_obs:endY_obs)]]-273.15, function(x) {mean((x)>25)}))
names(BIOCLIM)[nlyr(BIOCLIM)] = 'temp_sum'


### mean precipitation
BIOCLIM = c(BIOCLIM, app(PREC[[which(yrs%in%staY_obs:endY_obs)]], mean))
names(BIOCLIM)[nlyr(BIOCLIM)] = 'prec_mean'


##### std precipitation
BIOCLIM = c(BIOCLIM, app(PREC[[which(yrs%in%staY_obs:endY_obs)]], sd))
names(BIOCLIM)[nlyr(BIOCLIM)] = 'prec_std'


##### max precipitation
BIOCLIM = c(BIOCLIM, app(PREC[[which(yrs%in%staY_obs:endY_obs)]], max))
names(BIOCLIM)[nlyr(BIOCLIM)] = 'prec_max'


##### min precipitation
BIOCLIM = c(BIOCLIM, app(PREC[[which(yrs%in%staY_obs:endY_obs)]], min))
names(BIOCLIM)[nlyr(BIOCLIM)] = 'prec_min'



### months without precipitation
BIOCLIM = c(BIOCLIM, app(PREC[[which(yrs%in%staY_obs:endY_obs)]], function(x) {mean(x==0)}))
names(BIOCLIM)[nlyr(BIOCLIM)] = 'prec_no'



### mean evaporation
BIOCLIM = c(BIOCLIM, app(EVAP[[which(yrs%in%staY_obs:endY_obs)]], mean))
names(BIOCLIM)[nlyr(BIOCLIM)] = 'evap_mean'


##### std evaporation
BIOCLIM = c(BIOCLIM, app(EVAP[[which(yrs%in%staY_obs:endY_obs)]], sd))
names(BIOCLIM)[nlyr(BIOCLIM)] = 'evap_std'


##### max evaporation
BIOCLIM = c(BIOCLIM, app(EVAP[[which(yrs%in%staY_obs:endY_obs)]], max))
names(BIOCLIM)[nlyr(BIOCLIM)] = 'evap_max'


##### min evaporation
BIOCLIM = c(BIOCLIM, app(EVAP[[which(yrs%in%staY_obs:endY_obs)]], min))
names(BIOCLIM)[nlyr(BIOCLIM)] = 'evap_min'



##### maximal snow cover
BIOCLIM = c(BIOCLIM, app(SNOW[[which(yrs%in%staY_obs:endY_obs)]], max))
names(BIOCLIM)[nlyr(BIOCLIM)] = 'snow_max'




##### months with snow cover > 50%
BIOCLIM = c(BIOCLIM, app(SNOW[[which(yrs%in%staY_obs:endY_obs)]], function(x) {mean(x>50)}))
names(BIOCLIM)[nlyr(BIOCLIM)] = 'snow_dur'



##### add topographic and land cover variables
BIOCLIM = c(BIOCLIM, TOPO, LACO)





######
###### Train maxent model on bioclimatic data
######

# get coordintes of points falling in population polygons
sf_use_s2(F)
grid = st_make_grid(pop_poly, cellsize = c(0.05,0.05)) # create a 5-by-5 km grid
pop_grid = st_intersection(st_cast(pop_poly), st_cast(grid)) # find points within polygons
pop_coord = st_coordinates(st_centroid(pop_grid)) # get coordinates

### train maxent model
Maxent_model = maxent(stack(BIOCLIM), p=pop_coord)




######
###### Build prediction set for years of interest
######

## prepare object to store predicted habitat maps
Habitat_maps = rast()


for (y in yoi) {
  
  print(y)
  
  ##### mean temperature
  BIOCLIM_FUT = app(TEMP[[which(yrs%in%as.character((y-years_span):y))]]-273.15, mean)
  names(BIOCLIM_FUT)[nlyr(BIOCLIM_FUT)] = 'temp_mean'
  
  ##### std temperature
  BIOCLIM_FUT = c(BIOCLIM_FUT, app(TEMP[[which(yrs%in%as.character((y-years_span):y))]], sd))
  names(BIOCLIM_FUT)[nlyr(BIOCLIM_FUT)] = 'temp_std'
  
  ##### max temperature
  BIOCLIM_FUT = c(BIOCLIM_FUT, app(TEMP[[which(yrs%in%as.character((y-years_span):y))]]-273.15, max))
  names(BIOCLIM_FUT)[nlyr(BIOCLIM_FUT)] = 'temp_max'
  
  ### min temperature
  BIOCLIM_FUT = c(BIOCLIM_FUT, app(TEMP[[which(yrs%in%as.character((y-years_span):y))]]-273.15, min))
  names(BIOCLIM_FUT)[nlyr(BIOCLIM_FUT)] = 'temp_min'
  
  
  ### nb months with negative mean temperature
  BIOCLIM_FUT = c(BIOCLIM_FUT, app(TEMP[[which(yrs%in%as.character((y-years_span):y))]]-273.15, function(x) {mean((x)<0)}))
  names(BIOCLIM_FUT)[nlyr(BIOCLIM_FUT)] = 'temp_com'
  
  
  ### nb months with growing season  temperature (>5°)
  BIOCLIM_FUT = c(BIOCLIM_FUT, app(TEMP[[which(yrs%in%as.character((y-years_span):y))]]-273.15, function(x) {mean((x)>5)}))
  names(BIOCLIM_FUT)[nlyr(BIOCLIM_FUT)] = 'temp_gsm'
  
  
  ### nb months with growing season  temperature (>5°)
  BIOCLIM_FUT = c(BIOCLIM_FUT, app(TEMP[[which(yrs%in%as.character((y-years_span):y))]]-273.15, function(x) {mean((x)>25)}))
  names(BIOCLIM_FUT)[nlyr(BIOCLIM_FUT)] = 'temp_sum'
  
  
  ### mean precipitation
  BIOCLIM_FUT = c(BIOCLIM_FUT, app(PREC[[which(yrs%in%as.character((y-years_span):y))]], mean))
  names(BIOCLIM_FUT)[nlyr(BIOCLIM_FUT)] = 'prec_mean'
  
  
  ##### std precipitation
  BIOCLIM_FUT = c(BIOCLIM_FUT, app(PREC[[which(yrs%in%as.character((y-years_span):y))]], sd))
  names(BIOCLIM_FUT)[nlyr(BIOCLIM_FUT)] = 'prec_std'
  
  
  ##### max precipitation
  BIOCLIM_FUT = c(BIOCLIM_FUT, app(PREC[[which(yrs%in%as.character((y-years_span):y))]], max))
  names(BIOCLIM_FUT)[nlyr(BIOCLIM_FUT)] = 'prec_max'
  
  
  ##### min precipitation
  BIOCLIM_FUT = c(BIOCLIM_FUT, app(PREC[[which(yrs%in%as.character((y-years_span):y))]], min))
  names(BIOCLIM_FUT)[nlyr(BIOCLIM_FUT)] = 'prec_min'
  
  
  
  ### months without precipitation
  BIOCLIM_FUT = c(BIOCLIM_FUT, app(PREC[[which(yrs%in%as.character((y-years_span):y))]], function(x) {mean(x==0)}))
  names(BIOCLIM_FUT)[nlyr(BIOCLIM_FUT)] = 'prec_no'
  
  
  
  ### mean evaporation
  BIOCLIM_FUT = c(BIOCLIM_FUT, app(EVAP[[which(yrs%in%as.character((y-years_span):y))]], mean))
  names(BIOCLIM_FUT)[nlyr(BIOCLIM_FUT)] = 'evap_mean'
  
  
  ##### std evaporation
  BIOCLIM_FUT = c(BIOCLIM_FUT, app(EVAP[[which(yrs%in%as.character((y-years_span):y))]], sd))
  names(BIOCLIM_FUT)[nlyr(BIOCLIM_FUT)] = 'evap_std'
  
  
  ##### max evaporation
  BIOCLIM_FUT = c(BIOCLIM_FUT, app(EVAP[[which(yrs%in%as.character((y-years_span):y))]], max))
  names(BIOCLIM_FUT)[nlyr(BIOCLIM_FUT)] = 'evap_max'
  
  
  ##### min evaporation
  BIOCLIM_FUT = c(BIOCLIM_FUT, app(EVAP[[which(yrs%in%as.character((y-years_span):y))]], min))
  names(BIOCLIM_FUT)[nlyr(BIOCLIM_FUT)] = 'evap_min'
  
  
  
  ##### maximal snow cover
  BIOCLIM_FUT = c(BIOCLIM_FUT, app(SNOW[[which(yrs%in%as.character((y-years_span):y))]], max))
  names(BIOCLIM_FUT)[nlyr(BIOCLIM_FUT)] = 'snow_max'
  
  

  ##### months with snow cover > 50%
  BIOCLIM_FUT = c(BIOCLIM_FUT, app(SNOW[[which(yrs%in%as.character((y-years_span):y))]], function(x) {mean(x>50)}))
  names(BIOCLIM_FUT)[nlyr(BIOCLIM_FUT)] = 'snow_dur'  
  
  
  ##### add topographic and land cover variables
  BIOCLIM_FUT = c(BIOCLIM_FUT, TOPO, LACO)
  
  
  
  ######### run predictions
  habitat_y <- predict(Maxent_model, stack(BIOCLIM_FUT))
  
  ## add to container
  Habitat_maps = c(Habitat_maps, rast(habitat_y))


}

names(Habitat_maps) = paste0('y',yoi)

### Set a cut-off value for habitat suitability
Habitat_maps = Habitat_maps>0.5


# create output director
directory=paste(outputFolder,'/habitat_maps', sep="")
dir.create(directory)

#### Create local raster output for every population

for (pop in pop_poly$pop) {
  
  print(pop)
  
  # crop rasters to pop extent
  HM_pop = crop(Habitat_maps, pop_poly[pop_poly$pop==pop,], mask=T)
  
  # write output
  terra::writeRaster(HM_pop, filename = paste0(directory,pop,'.tif'), gdal=c("COMPRESS=DEFLATE", "TFW=YES"), filetype = "COG", overwrite=T)
  
}

output <- list('climate_map'= directory
)

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))
