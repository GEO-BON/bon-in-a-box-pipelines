 
## Environment variables available
# Script location can be used to access other scripts
print(Sys.getenv("SCRIPT_LOCATION"))

## Install required packages
packages <- c("rjson", "rstac")


new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)
 library("rstac")

 library("rjson")
 ## Receiving args
args <- commandArgs(trailingOnly=TRUE)
outputFolder <- args[1] # Arg 1 is always the output folder
cat(args, sep = "\n")


input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)

 s <- stac(input$stac_path)
 print("s")
 it_obj <- s |>
  stac_search(bbox=c(-120,30,-40,68), collections=c('chelsa-clim'),limit=5000) |> get_request()
print("it_obj")
st<-stac_image_collection(it_obj$features,asset_names=c("bio2"))

print("st")
v = cube_view(srs = "EPSG:32198",  extent = list(t0 = "1981-01-01", t1 = "1981-01-31",
                                                 left = -2009488, right = 1401061,  top = 2597757, bottom = -715776),
              dx = 2000, dy = 2000, dt = "P1Y",aggregation = "mean", resampling = "near")
print("v")
