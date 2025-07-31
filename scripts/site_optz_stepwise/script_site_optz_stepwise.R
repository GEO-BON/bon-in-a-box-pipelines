library(rjson)

if (!'SURDES' %in% installed.packages()) {
  install.packages("SURDES", repos="http://R-Forge.R-project.org", force = TRUE)
  
}else{
  print("SURDES package installed locally, not in CONDA")
}

library(ggplot2)

#read inputs
input <- biab_inputs()  

# get environmental layers from BiaB form
# assumed chelsa layers in WGS84
# warning if layers are not WGS84
print("Calling joint distance and environmental distance matrix of sites")
mdist <- as.matrix(read.csv(input$mdist) ) ######

print("Vis mdist 10x10")

print(mdist[1:10,1:10])


print("Loading observtion locations / sampling sites and vectorizing them") ## need to call an external file
# or the sampling selection pipeline???? ask BiaB team 

locs_df <- read.csv(input$locations_csv) ######
print(locs_df)


#df file should have lat lon and vini columns
locs <- terra::vect(locs_df, geom = c("lon", "lat"),crs = "EPSG:4326")
#EPSG <- as.character(input$EPSG)
predictors <- terra:: rast(c(input$rasters))
print(predictors)

res_fact<- as.numeric(input$res_fact)
iters<- as.numeric(input$iters)


#reproject to working EPSG 
locs<- terra::project(locs, predictors)

#get 1 predictor for base raster
print("calling one predictor from stack of rasters")
temperature <- predictors[[1]]

er <- terra::rast(terra::ext(temperature), resolution= terra::res(temperature)) 
terra::crs(er) <- terra::crs(temperature)

res_fact <- input$res_fact
#aggregate to 10 km fo ease of processing
rr <- terra::aggregate(er, res_fact)

set.seed(1234)



conditions <- rep(  1, nrow(locs_df))

#producing flat conditions
print("#producing flat conditions for all sites (may customize after)")
df_cond<-as.data.frame(t(conditions))
row.names(df_cond) <-"cond1"
conditions<-unname(as.matrix(df_cond))
#class(conditions)
row.names(conditions) <-"cond1"
criteria <- "min"

##########################################
# vini based on differences of visited sites, skip this if already saved

#visited sites in the last 10 years = make 1
#sites visited and not anymore, prior to 10 years make =0 
vini <- locs_df$vini


print(paste("starting SURDES algo", Sys.time()))
system.time({
  result <- SURDES::alloc(mdist=mdist, vini= vini, 
                          criteria=criteria, 
                          conditions=conditions, iter=iters)
})

print(paste("finished SURDES algo of variable at", Sys.time()))

print(paste("plotting point selection of surdes", Sys.time()))
point_Sel <- colSums(result$selmatrix)
#plot(1:length(point_Sel), point_Sel)

#BBS_surdes_point_Sel <-ggplot2::ggplot()+
 # ggplot2::geom_point(ggplot2::aes(1:length(point_Sel), point_Sel), pch= 21)+
  #ggplot2::theme_bw()+
  #ggplot2::ggtitle("BBS locations demand points covered variance")


print(paste("plotting uncovered variance curve of surdesof variable at", Sys.time()))
uncov <- rowSums(result$pmmatrix)
#plot(1:length(uncov), uncov)

surdes_uncov <-ggplot2::ggplot()+
  ggplot2::geom_point(ggplot2::aes(1:length(uncov), uncov), pch= 21)+
  ggplot2::theme_bw()+
  ggplot2::ggtitle("Locations demand points uncovered variance")



##BiaB OUTPUTS

#save output of point selection
point_Sel_path<-file.path(outputFolder, "point_Sel.csv") 
write.csv(point_Sel, point_Sel_path, row.names = FALSE )
biab_output("point_Sel", point_Sel_path)

#save output of uncovered variance
uncov_path<-file.path(outputFolder, "uncov.csv") 
write.csv(uncov, uncov_path, row.names = FALSE )
biab_output("uncov", uncov_path)



#save plot composite_star_map
surdes_uncov_path <- file.path(outputFolder, "surdes_uncov.png")



ggplot2::ggsave(surdes_uncov, filename = surdes_uncov_path, 
                width = 10,
                height = 5,
                dpi = 300,
                bg = "white")


biab_output("surdes_uncov", surdes_uncov_path)

