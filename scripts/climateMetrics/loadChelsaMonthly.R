## Script to query the monthly chelsa data and send to load to stac
library(gdalcubes)
library(sf)
library(lubridate)

input <- biab_inputs()

# Source load cube function
source(paste(Sys.getenv("SCRIPT_LOCATION"), "/data/loadCubeFunc.R", sep = "/"))

bbox <- st_bbox(c(xmin = input$bbox[1], ymin = input$bbox[2], 
        xmax = input$bbox[3], ymax = input$bbox[4]), crs = st_crs(input$srs_cube))

n_year <- as.integer(substr(input$t1, 1, 4)) - as.integer(substr(input$t0, 1, 4)) + 1 
temporal_res <- paste0("P", n_year, "Y")
print(temporal_res)

## Call function


cube_current <- load_cube(
stac_path = "https://stac.geobon.org/",
collections = 'chelsa-monthly',
bbox = bbox,
t0 = input$t0,
layers = NULL,
mask = NULL,
t1 = input$t1,
ids = NULL,
limit = 5000,
variable = "tas",
srs.cube = input$srs_cube,
spatial.res = input$spatial_res, # in meters
temporal.res = temporal_res, # see number of years t0 to t1
aggregation = input$aggregation,
resampling = "bilinear"
                         )

 out<-gdalcubes::write_tif(cube_current, dir = file.path(outputFolder), prefix = "current_climate", creation_options = list("COMPRESS" = "DEFLATE"), 
      COG=TRUE, write_json_descr=TRUE)

biab_output("current_climate", file.path(out[1]))

