library(rjson)
library(remotes)
if (!'spbal' %in% installed.packages()) {
  remotes::install_github("https://github.com/docgovtnz/spbal.git", force = TRUE)
}else{
  print("spbal package installed locally, not in CONDA")
}

library(spbal)
library(terra)
library(sf)
library(tidyterra)
library(ggplot2)


#read inputs
input <- biab_inputs()  

#Sampling site selection using BAS
print("Calling raster of blocks and map shape polygon")
country_rast <- terra::rast(input$rast_blocks)

country_poly <- sf::st_read(input$country_polygon)
country_poly <- sf::st_transform(country_poly,  terra::crs(country_rast)) ##check if it run on BiaB!!!!!!!!

#plot(country_poly)
print("Getting bounding box for BAS")

bb <- spbal::BoundingBox(shapefile = country_poly)

## Draw a bunch of seeds for speed.
print("Generating seeds for BAS")

system.time({
  seeds <- spbal::findBASSeed(country_poly, bb, n = 100)
})

print("Based on 1000 samples drawing BAS points from polygon")

n_samples <- 10000 ## Big oversample
system.time({
  result <- spbal::BAS(shapefile = country_poly,
                       n = n_samples,
                       seeds = seeds[1,], ## Change to something else for a fast new random sample.
                       boundingbox = bb)
})

seed3 <- sample(10000, 1)

print("Calling raster of blocks and map shape polygon")

h3 <- spbal::cppBASpts(n = n_samples, seeds = seed3, bases = 5)

## Okay now assign some inlucsion probabilities:
ndesign <- input$ndesign
ngrps <- length(unique(terra::values(country_rast))[!is.na(unique(terra::values(country_rast)))])

Ngrps<-terra::freq(country_rast)

# Ngrps[Ngrps < 1000 & Ngrps > 0] <- 100 ## Set these to all be the same for these really small types.
Ngrps$pincl <- 1/log(Ngrps$count/100) ## Instead just scale it as inverse log of the number of points (scaling less sever by /100)

# pincl[Ngrps == 0] <- 0
Ngrps$pincl [abs(Ngrps$pincl ) == Inf] <- 0 ## Remove those 1/log(0) points. as 0.

Ngrps$pincl_scaled <- Ngrps$pincl/max(Ngrps$pincl)  ## Scale it.

## Now take an unequal prob sample:
bas_points <- terra::vect(result$sample)

print("Extracting points from block classes")
grps <- terra::extract(country_rast, terra::project(bas_points, country_rast))

keep <- merge(grps, Ngrps, by.x = "Block", by.y = "value")$pincl_scaled > h3$pts ## Check against random uniform halton points in 3rd dimension.

pts <- result$sample[keep == TRUE,][1:ndesign,] ## Keep the ndesign points.


##Two plots for mapping points
country_vect<- terra::vect(input$country_polygon)

print("Creating blank map and points")
pts_df <- terra::as.data.frame(terra::vect(pts), geom = "XY")
pts_df<-pts_df[,c("x","y")]
print(head(pts_df))

blnk_map <-ggplot2::ggplot()+
  tidyterra::geom_spatvector(data = country_poly, alpha = 0.5)+
  tidyterra::geom_spatvector(data = terra::vect(pts))

print("Cleaning empty values of raster for df plotting")
merged_df<-terra::as.data.frame(country_rast, xy=TRUE, na.rm = TRUE)
merged_df<-merged_df[complete.cases(merged_df[, 3]),]
print(head(merged_df))

set.seed(1)
colors_vect<-(sample( grDevices::colors()[grep('gr(a|e)y', grDevices::colors(), invert = T)], length(unique(merged_df$Block)) )  )

print("Creating raster map and points")

block_map<-ggplot2::ggplot()+
  #tidyterra::geom_spatvector(data=country_vect )+
  ggplot2::geom_raster(data = merged_df[,c("x", "y", "Block")], 
                       ggplot2::aes(x=x, 
                                    y = y, 
                                    fill =as.factor(Block)) )+ #make factor if using manual scale
  ggplot2::scale_fill_manual(values =colors_vect,na.value = "transparent")+
  # ggplot2::scale_fill_viridis_c(option = "turbo")+
  #ggplot2::xlim(range(merged_df[,c("x")]))+
  #ggplot2::ylim(range(merged_df[,c("y")]))+
  ggplot2::theme_bw()+
  ggplot2::theme(legend.position = "none",
                 axis.text.y = ggplot2::element_blank(),
                 axis.text.x = ggplot2::element_blank()
  )+
  tidyterra::geom_spatvector(data = terra::vect(pts))

maps_output <- cowplot::plot_grid(blnk_map, block_map, nrow=1)

pts_df <- terra::as.data.frame(terra::vect(pts), geom = "XY")
pts_df<-pts_df[,c("x","y")]

#save plot
maps_path <- file.path(outputFolder, "maps_output.png") 
ggplot2::ggsave(maps_output, filename= maps_path,
                height = 5, width = 10, units = "in" , dpi = 300, bg ="white")
biab_output("maps_output", maps_path)

#save output ofselected points
pts_df_path<-file.path(outputFolder, "pts_selected_df.csv") 
write.csv(pts_df, pts_df_path )
biab_output("pts_df", pts_df_path)


#save shapefile of points
points_shape<-terra::project(terra::vect(pts), "EPSG:4326")
points_shape_path <- file.path(outputFolder, "points_shape.GeoJSON") 
writeVector(points_shape, points_shape_path, overwrite=TRUE)
biab_output("points_shape", points_shape_path)
