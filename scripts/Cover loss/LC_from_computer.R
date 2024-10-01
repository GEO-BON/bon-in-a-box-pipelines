###inatall packages
packages <- c("raster", "rjson", "stringr","geojsonsf", "ggOceanMaps")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)
if(!"rgdal"%in% installed.packages()){
  install.packages("rgdal", repos="http://R-Forge.R-project.org", type="source")
}
if(!"gdalUtils"%in% installed.packages()){
  library(devtools)
  devtools::install_github("gearslaboratory/gdalUtils")
}
library(raster)
library(stringr)
library(geojsonsf)
library(rjson)
library(ggOceanMaps)
library(gdalUtils)


##Hello
### Receiving arguments from input.json.
input <- fromJSON(file=file.path(outputFolder, "input.json"))

bbox<-input$bbox
print(bbox)
create_path<-function(bbox, covertype){
  if(round_any(bbox[4],10, f=ceiling)>=0){
    if(bbox[1]<0){
      out<-paste("/userdata/",covertype,"/Hansen_GFC-2023-v1.11_",covertype,"_",round_any(bbox[4],10, f=ceiling),
            "N_",str_pad(round_any(abs(bbox[1]), 10, f=ceiling),3, pad = "0"),"W.tif", sep="")
    }
    if(round_any(bbox[1], 10, f=floor)>=0){
      out<-paste("/userdata/",covertype,"/Hansen_GFC-2023-v1.11_",covertype,"_",str_pad(round_any(bbox[4],10, f=ceiling),2, pad = "0"),
            "N_",str_pad(round_any(abs(bbox[1]), 10, f=floor),3, pad = "0"),"E.tif", sep="")
    }
  }
  if(round_any(bbox[4],10, f=ceiling)<0){
    if(bbox[1]<0){
      out<-print(paste("/userdata/",covertype,"/Hansen_GFC-2023-v1.11_",covertype,"_",round_any(abs(bbox[4]),10, f=floor),
            "S_",str_pad(round_any(abs(bbox[1]), 10, f=ceiling),3, pad = "0"),"W.tif", sep=""))
    }
    if(round_any(bbox[1], f=floor, 10)){
      out<-print(paste("/userdata/",covertype,"/Hansen_GFC-2023-v1.11_",covertype,"_",str_pad(round_any(bbox[4],10, f=ceiling),2, pad = "0"),
            "S_",str_pad(round_any(abs(bbox[1]), f=floor, 10),3, pad = "0"),"E.tif", sep=""))
    }
  }
  return(out)
}
print(create_path(bbox,"treecover2000"))
print(create_path(bbox,"lossyear"))

gdalwarp(srcfile = create_path(bbox,"treecover2000"),
             dstfile = file.path(outputFolder, "TC.tif"),
             tr = c(0.01, 0.01),
             r = "average")
gdalwarp(srcfile = create_path(bbox,"lossyear"),
         dstfile =file.path(outputFolder, "tree_cover_loss.tif"),
         tr = c(0.01, 0.01),
         r = "average")

tree_cover_loss_crop_p<-file.path(outputFolder, "tree_cover_loss.tif")
TC_crop_p<-file.path(outputFolder, "TC.tif")
# ###Write Files
# writeRaster(tree_cover_loss, tree_cover_loss_crop_p, format = "GTiff")
# writeRaster(TC, TC_crop_p, format = "GTiff")

## Outputing result to JSON
output <- list("tree_cover_loss"=tree_cover_loss_crop_p, "TC"=TC_crop_p)

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))


