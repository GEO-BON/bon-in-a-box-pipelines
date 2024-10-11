

## Install required packages

## Load required packages

#memtot<-as.numeric(system("awk '/MemTotal/ {print $2}' /proc/meminfo", intern=TRUE))/1024^2
#memallow<-floor(memtot*0.9) # 90% of total available memory
#print(paste0(memallow,"G of RAM allowed to Java heap space"))
#options(java.parameters = paste0("-Xmx",memallow,"g"))

library("terra")
library("rjson")
library("raster")
library("dplyr")
library("gdalcubes")
library("ENMeval")
library("devtools")
library("sf")
if (!"stacatalogue" %in% installed.packages()[,"Package"]) devtools::install_github("ReseauBiodiversiteQuebec/stac-catalogue")
if (!"gdalcubes" %in% installed.packages()[,"Package"]) devtools::install_github("appelmar/gdalcubes_R")
if (!"INLA" %in% installed.packages()[,"Package"]) install.packages("INLA",repos=c(getOption("repos"),INLA="https://inla.r-inla-download.org/R/stable"), dep=TRUE)
if (!"ewlgcpSDM" %in% installed.packages()[,"Package"]) devtools::install_github("frousseu/ewlgcpSDM")
library("stacatalogue")
library(INLA)
library(ewlgcpSDM)


## Load functions
source(paste(Sys.getenv("SCRIPT_LOCATION"), "SDM/runMaxentFunc.R", sep = "/"))
source(paste(Sys.getenv("SCRIPT_LOCATION"), "SDM/sdmUtils.R", sep = "/"))


input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs : ")
print(input)

presence_background <- read.table(file = input$presence_background, sep = '\t', header = TRUE, check.names = FALSE) 
predictors <- terra::rast(unlist(input$predictors))


# Create study region from the bounding box of predictors
region <- st_bbox(predictors) |> st_as_sfc() |> st_as_sf()

# First, we delineate a non-convex hull around the study area that we will use to create an INLA mesh.
domain <- st_sample(st_buffer(region, 5000), 5000)
domain <- inla.nonconvex.hull(st_coordinates(domain), convex = -0.015, resolution = 75)

# We then create the INLA mesh over the study area. We use a coarse resolution for the mesh edges corresponding to approximately 1% of the study area diameter and a relatively large outer area for reducing edge effects. See [virgilio]() for advices on creating a good mesh.
pedge <- 0.005
edge <- min(c(diff(st_bbox(region)[c(1, 3)]) * pedge, diff(st_bbox(region)[c(2, 4)]) * pedge))

mesh <- inla.mesh.2d(loc.domain = NULL, 
                     max.edge = c(edge, edge * 3), 
                     min.angle = 21,
                     cutoff = edge / 1,
                     offset = c(edge, edge * 3),
                     boundary = domain,#inla.mesh.segment(domainloc),
                     crs = st_crs(region))

### Create dual mesh
params <- dmesh_mesh(mesh)  

### Compute weights
params <- dmesh_weights(params, region)

### Summarize predictors
params <- dmesh_predictors(params, predictors)

### Create an exclusion buffer
obs <- st_as_sf(presence_background[presence_background$pa == 1, ], coords = c("lon", "lat"), crs = input$proj)
buff <- st_buffer(obs, 250000) |> st_union()

### Gather effort
bg <- st_as_sf(presence_background, coords = c("lon", "lat"), crs = input$proj)
params <- dmesh_effort(params, obs = obs, background = bg, buffer = buff, adjust = FALSE)

print(head(params$predictors))
cat("\n")
print(head(params$effort))

f <- as.formula(paste("y ~", paste(names(params$predictors), collapse = " + ")))

### Run model
m <- ewlgcp(
  formula = f,
  dmesh = params,
  effort = TRUE,
  adjust = FALSE,
  buffer = TRUE,
  orthogonal = TRUE,
  prior.beta = NULL,
  prior.range = c(5000, 0.01),
  prior.sigma = c(0.00001, NA),
  smooth = 2,
  num.threads = 2:2,
  #blas.num.threads=2,
  control.inla = list(
    strategy = "adaptive", # "adaptive"
    int.strategy = "eb", # "eb"
    huge = FALSE, # apparently ignored
    control.vb = list(
      enable = TRUE,
      verbose = FALSE
    )
  ),# adaptive, eb
  inla.mode = "experimental",
  control.compute = list(config = TRUE, openmp.strategy = "pardiso"),
  verbose = FALSE,
  safe = FALSE
)

print(m$summary.fixed)

### Map predictions
sdms <- ewlgcpSDM::map(model = m,
                    dmesh = params,
                    dims = c(1500, 1500),
                    region = region
)

sdms <- mask(sdms, vect(region))
crs(sdms) <- crs(region)


sdm_pred <- sdms[["mean"]]
names(sdm_pred) <- "prediction"
sdm_runs <- sdms[[c("0.025quant", "0.975quant")]]

### temporary rescaling to display in the 0-1 viewer
#sdm_pred <- sdm_pred / global(sdm_pred,"max", na.rm = TRUE)[1,1]

#print(sdm_pred)

pred.output <- file.path(outputFolder, "sdm_pred.tif")
runs.output <- paste0(outputFolder,"/sdm_runs_", 1:nlyr(sdm_runs), ".tif")
#runs.output <- file.path(outputFolder, "sdm_runs.tif")

terra::writeRaster(x = sdm_pred,
                          filename = pred.output,
                          filetype = "COG",
                          wopt= list(gdal=c("COMPRESS=DEFLATE")),
                          overwrite = TRUE)
for (i in 1:nlyr(sdm_runs)){
    terra::writeRaster(x = sdm_runs[[i]],
    filename = file.path(outputFolder, paste0("/sdm_runs_", i, ".tif")),
    filetype = "COG",
    wopt= list(gdal=c("COMPRESS=DEFLATE")),
    overwrite = TRUE)
}


output <- list("sdm_pred" = pred.output,
  "sdm_runs" = runs.output) 

jsonData <- toJSON(output, indent = 2)
write(jsonData, file.path(outputFolder, "output.json"))