# Load libraries in CRAN
packages_list <- list("terra", "rjson", "raster", "dplyr", "gdalcubes", "ENMeval", "devtools", "sf", "FNN", "stars")
lapply(packages_list, library, character.only = TRUE)

# Load libraries from external sources
if (!"INLA" %in% installed.packages()[,"Package"]) install.packages("INLA",repos=c(getOption("repos"),INLA="https://inla.r-inla-download.org/R/stable"), dep=TRUE)
if (!"ewlgcpSDM" %in% installed.packages()[,"Package"]) devtools::install_github("BiodiversiteQuebec/ewlgcpSDM")

packages_list <- list("INLA", "ewlgcpSDM")
lapply(packages_list, library, character.only = TRUE)

input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs : ")
print(input)
crs <- paste0(input$bbox_crs$CRS$authority, ":", input$bbox_crs$CRS$code)

presence_background <- read.table(file = input$presence_background, sep = '\t', header = TRUE, check.names = FALSE)
predictors <- terra::rast(unlist(input$predictors))

# Create study region from the bounding box of predictors
region <- st_bbox(predictors) |> st_as_sfc() |> st_as_sf()

# First, we delineate a non-convex hull around the study area that we will use to create an INLA mesh.
domain <- st_sample(st_buffer(region, 5000), 5000)
domain <- inla.nonconvex.hull(st_coordinates(domain), convex = -0.015, resolution = 75)

# We then create the INLA mesh over the study area. We use a coarse resolution for the mesh edges corresponding to approximately 1% of the study area diameter and a relatively large outer area for reducing edge effects. See [virgilio]() for advices on creating a good mesh.
pedge <- 0.01
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
print(colnames(params$predictors))

### Create an exclusion buffer
obs <- st_as_sf(presence_background[presence_background$pa == 1, ], coords = c("lon", "lat"), crs = crs)
buff <- st_buffer(obs, 250000) |> st_union()

### Gather effort
bg <- st_as_sf(presence_background, coords = c("lon", "lat"), crs = crs)
params <- dmesh_effort(params, obs = obs, background = bg, buffer = buff, adjust = FALSE)

print(head(params$predictors))
cat("\n")
print(head(params$effort))
names(params$predictors) <- make.names(names(params$predictors))

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


sdm_pred <- sdms#[["mean"]]
#names(sdm_pred) <- "prediction"
sdm_ci <- sdms[["0.975quant"]] - sdms[["0.025quant"]]

### temporary rescaling to display in the 0-1 viewer
#sdm_pred <- sdm_pred / global(sdm_pred,"max", na.rm = TRUE)[1,1]

#print(sdm_pred)

pred.output <- file.path(outputFolder, "sdm_pred.tif")
ci.output <- file.path(outputFolder, "sdm_ci.tif")
unc.output <- file.path(outputFolder, "sdm_unc.tif")
obs.output <- file.path(outputFolder, "sdm_obs.geojson")
bg.output <- file.path(outputFolder, "sdm_bg.geojson")
dmesh.output <- file.path(outputFolder, "sdm_dmesh.geojson")

terra::writeRaster(x = sdm_pred[["mean"]],
                          filename = pred.output,
                          filetype = "COG",
                          wopt= list(gdal=c("COMPRESS=DEFLATE")),
                          overwrite = TRUE)

terra::writeRaster(x = sdm_pred,
                          filename = unc.output,
                          filetype = "COG",
                          wopt= list(gdal=c("COMPRESS=DEFLATE")),
                          overwrite = TRUE)

terra::writeRaster(x = sdm_ci,
                          filename = ci.output,
                          filetype = "COG",
                          wopt= list(gdal=c("COMPRESS=DEFLATE")),
                          overwrite = TRUE)

sf::st_write(st_transform(obs, 4326), obs.output, append = FALSE)
sf::st_write(st_transform(bg, 4326), bg.output, append = FALSE)
sf::st_write(st_transform(params$dmesh, 4326), dmesh.output, append = FALSE)

output <- list("sdm_pred" = pred.output,
  "sdm_unc" = unc.output,
  "sdm_ci" = ci.output,
  "sdm_obs" = obs.output,
  "sdm_bg" = bg.output,
  "sdm_dmesh" = dmesh.output
  )

jsonData <- toJSON(output, indent = 2)
write(jsonData, file.path(outputFolder, "output.json"))