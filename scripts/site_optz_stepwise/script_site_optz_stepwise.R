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
locs_input <- input$locations_csv

if(locs_input == "Peru sample"){
  data <- data.frame(
    lon = c(-78.03548959, -73.28544833, -76.45068811, -70.02099481, -74.0985234, -72.42927676, -75.67469561, -74.48498931, -71.27682106, -69.69802904, -79.98015578, -73.65864444, -75.27250752, -74.68495501, -73.07326686, -76.25871746, -73.88637474, -77.03644251, -70.64487716, -78.63036063, -75.47895983, -72.69717647, -75.86070809, -69.44645655, -73.51285784, -70.29938964, -78.21590307, -75.07801626, -75.07530219, -71.81321496, -73.50655454, -77.43551133, -72.6807651, -75.86070758, -74.683159, -76.27124379, -73.88806612, -77.03143609, -81.13921358, -74.87525083, -78.03774595, -71.75133154, -69.9564245, -74.09336046, -72.4632458, -75.66675291, -77.62374515, -71.2358816, -72.92288846, -76.07933995, -70.57250413, -75.27030693, -68.88800415, -71.77909883, -73.34762839, -76.56478263, -70.28011857, -74.18710078, -74.5742566, -77.7350688, -72.98714985, -73.80312402, -75.37600971, -74.7782123, -77.91372737, -73.21747659, -70.00089, -80.26775222, -70.87021131, -69.06992505, -74.38878828, -75.96035263, -73.57935277, -76.74404745, -70.31002234, -72.04093027, -73.44325828, -76.59117278, -70.21670108, -71.05570982, -75.816194, -74.63273351, -73.81741748, -76.99946306, -72.23593089, -75.41850924, -74.83011333, -76.41867592, -74.0375584, -78.76198496, -69.24466209, -80.71296697, -77.60401077, -71.30723085, -73.65255623, -72.0162957, -75.22299551, -74.92687961, -71.69631702, -73.36342821),
    lat = c(-7.864562188, -11.27160552, -5.152676256, -15.30115183, -3.112872558, -16.70048408, -10.59568687, -8.555456763, -12.61077322, -11.68085044, -5.586708458, -15.80585041, -1.525685565, -4.927475657, -13.08293384, -6.966831327, -10.36775862, -4.244510422, -14.40989947, -8.312462067, -12.40964241, -10.0593697, -3.944372844, -14.08376148, -1.903050632, -11.390023, -5.2971533, -9.387179298, -7.346438299, -16.84278222, -4.623599625, -6.660146023, -11.87158889, -5.758419556, -3.717974912, -11.19828167, -9.158742454, -3.035744349, -4.373095243, -14.60120672, -8.468396305, -2.353475374, -17.70901734, -5.531600723, -13.68159578, -7.572693746, -4.846860528, -15.02333577, -2.809014581, -13.01232018, -4.159117449, -2.13046672, -12.26607757, -12.21488244, -16.3071365, -10.18959963, -4.056961259, -8.151874248, -13.59348729, -7.463950369, -10.86691818, -2.709479905, -12.00679775, -9.966543896, -3.839037281, -1.802020041, -11.28468485, -5.182717275, -3.155404646, -16.68157438, -4.524123779, -6.564447442, -11.77680682, -5.655658792, -15.80959238, -3.612394631, -9.056365722, -2.935728382, -13.0960305, -10.39577052, -8.378596063, -6.338468731, -14.19537422, -8.072220036, -11.46499165, -5.355768371, -3.314836676, -10.7946847, -8.756127282, -6.702109548, -11.87267255, -5.780612669, -9.880963199, -3.760575196, -5.127712504, -13.27412698, -7.170020582, -10.57120991, -14.62815607, -2.406695824),
    vini = c(1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
  ) 
}else{
  locs_df <- read.csv(input$locations_csv) ###### this would load a predefined csv file
}


print("View sample of loaded CSV file of locations (should contain VINI vector of 0s and 1s)")
head(locs_df)


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

