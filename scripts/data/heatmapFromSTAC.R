## Script to download heatmaps from STAC
# and uses the 'predictors' argument

## Install required packages
packages <- c("terra", "rjson", "raster", 
              "stars", "gdalcubes", "rstac", "downloader")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

library("terra")
library("rjson")
library("raster")
library("stars")
library("rstac")
library("gdalcubes")
library("downloader")

## Receiving args
args <- commandArgs(trailingOnly=TRUE)
outputFolder <- args[1] # Arg 1 is always the output folder
cat(args, sep = "\n")

setwd(outputFolder)

input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)


stacURL <- "https://io.biodiversite-quebec.ca/stac/"
taxa <- input$taxa

# Check if blank of NULL
# Sometimes it has more than one raster provided, so check ind 1
if(is.null(input$predictors[1]) || input$predictors[1]==""){
  predictors <- NULL
}else{
  predictors <- terra::rast(input$predictors)
}

fout <- file.path(outputFolder, paste0("heatmapGBIF-",taxa,".tif"))

if(!is.null(predictors)){
  s <- stac(stacURL)
      
  it_obj <- s |>
    stac_search(collections=c('gbif_heatmaps'),limit=5000) |> get_request()

  st <- gdalcubes::stac_image_collection(it_obj$features,asset_names=c("data"), 
                                         property_filter=function(f){f$taxa==taxa})

  # Get extent
  ee = as.list(ext(predictors))
  names(ee) = c("left", "right", "bottom", "top")
  # Add time
  ee[["t0"]] = "2006-01-01"
  ee[["t1"]] = "2006-01-01"

  v = cube_view(srs = crs(predictors, proj = T),
                extent = ee,
                dx = xres(predictors), dy = yres(predictors), dt = "P1D", 
                aggregation= "mean", resampling = "bilinear")

  gdalcubes_options(parallel=TRUE)

  raster_cube(st, v) |> 
    write_tif() |> 
    terra::rast() -> raster.out

  writeRaster(raster.out, fout, overwrite = T)

}else{
  # Just download the file (some issues using rstac/gdalcubes)
  dlink <- paste0(
      "https://object-arbutus.cloud.computecanada.ca/bq-io/io/gbif_heatmaps/gbif_",
      taxa,
      "_density_06-2022.tif"
    )

  download(dlink, destfile = fout)
}


output <- list("raster" =  fout)
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))
