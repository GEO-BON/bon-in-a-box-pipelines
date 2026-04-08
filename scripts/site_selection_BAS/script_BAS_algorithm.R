library(rjson)
library(remotes)
#if (!'spbal' %in% installed.packages()) {
  remotes::install_github("https://github.com/docgovtnz/spbal.git", force = TRUE)
#}else{
 # print("spbal package installed locally, not in CONDA")
#}

library(spbal)
library(terra)
library(sf)
library(tidyterra)
library(ggplot2)

set.seed(1)
#read inputs
input <- biab_inputs()

#Sampling site selection using BAS
print("Calling raster of blocks and map shape polygon")
country_rast <- terra::rast(input$rast_blocks)

country_poly <- sf::st_read(input$country_polygon)

country_poly <- sf::st_transform(country_poly,  terra::crs(country_rast)) ##check if it run on BiaB!!!!!!!!
country_poly <- sf::st_crop(country_poly,  country_rast)

## Start BAS algotithm

#plot(country_poly)
print("Getting bounding box for BAS")

bb <- spbal::BoundingBox(shapefile = country_poly)

## Draw a seed for speed
print("Generating seeds for BAS")

seeds <- spbal::findBASSeed(country_poly, bb, n = 1)



options_bas <- input$options_bas
options_bas <- as.character(options_bas)
print(options_bas)

if (options_bas != "equal") {

  print("Based on 1000 samples drawing BAS points from polygon")

  n_samples <- 10000 ## Big oversample
  system.time({
    result <- spbal::BAS(shapefile = country_poly,
                         n = n_samples,
                         seeds = seeds, ## Change to something else for a fast new random sample.
                         boundingbox = bb)
  })
  print("Writing function to define incl probs")
  ## Function to select unequal probabiltiy samples via BAS:
  ## bas_sample: Output from call to spbal::BAS, must be an oversample.
  ## incl_rast: terra object with inclusion probabilities added.
  sample_unequal <- function(bas_sample, incl_raster, n_sample = 10){
    if(n_sample > nrow(bas_sample$sample))
      stop("Need to draw a bigger sample of BAS points to use this function.")
    rseed <- sample(10000, 1)
    np <- max(bas_sample$sample$SiteID)
    p <- spbal::cppBASpts(n = np, seeds = rseed, bases = 5)
    bas_sample$sample$pSelect <- p$pts[bas_sample$sample$SiteID]
    bas_points <- terra::vect(bas_sample$sample)
    bas_sample$sample$pincl <- terra::extract(incl_raster, terra::project(bas_points, incl_raster))$Block
    bas_sample$sample$pincl_scaled <- bas_sample$sample$pincl/max(bas_sample$sample$pincl)
    bas_sample$sample <- bas_sample$sample[bas_sample$sample$pincl_scaled > bas_sample$sample$pSelect,][1:n_sample,]
    return(bas_sample)
  }

  print("Defining parameters")
  ## Okay now assign some inclusion probabilities and make them into a raster:
  ndesign <- input$ndesign
  ngrps <- max(terra::values(country_rast), na.rm = TRUE)
  Ngrps <- unlist(lapply(1:ngrps, FUN = function(x){sum(terra::values(country_rast) == x,na.rm = TRUE)}))
  # Ngrps[Ngrps < 1000 & Ngrps > 0] <- 100 ## Set these to all be the same for these really small types.
  pincl <- log(Ngrps) ## Instead just scale it as inverse log of the number of points (scaling less sever by /100)
  pincl[Ngrps == 0] <- 0
  pincl[abs(pincl) == Inf] <- 0 ## Remove those 1/log(0) points. as 0.

  print(paste("ndesign = ", ndesign, "and ngrps ", ngrps))

  ## Now take an unequal prob sample:
  vals <- pincl[values(country_rast)]
  vals[is.na(vals)] <- 0
  country_rast2 <- country_rast
  values(country_rast2) <- vals

  print ("Running incl prob function on BAS sample")
  bas_sample <- sample_unequal(bas_sample = result, incl_raster = country_rast2, n_sample = ndesign)
  print(bas_sample$sample)

}else{
  print("Performing a BAS equal probability selection")
  system.time({
    bas_sample <- spbal::BAS(shapefile = country_poly,
                         n = input$ndesign,
                         seeds = seeds, ## Change to something else for a fast new random sample.
                         boundingbox = bb)
  })
}


##Two plots for mapping points
country_vect<- terra::vect(input$country_polygon)

print("Creating simple map and points")
pts_df <- terra::as.data.frame(terra::vect(bas_sample$sample), geom = "XY")
pts_df<-pts_df[,c("x","y")]
#print(head(pts_df))

blnk_map <-ggplot2::ggplot()+
  tidyterra::geom_spatvector(data = country_poly)+
  tidyterra::geom_spatvector(data = terra::vect(bas_sample$sample))

print("Cleaning empty values of raster for df plotting")
merged_df<-terra::as.data.frame(country_rast, xy=TRUE, na.rm = TRUE)
merged_df<-merged_df[complete.cases(merged_df[, 3]),]
print(head(merged_df))


colors_df<-read.csv(input$colors_vect)
colors_vect <-colors_df[,2]

#print(colors_vect)

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
  tidyterra::geom_spatvector(data = terra::vect(bas_sample$sample))

maps_output <- cowplot::plot_grid(blnk_map, block_map, nrow=1)

print("Reprojecting points to WGS84")
pts_df <- terra::as.data.frame(terra::project(terra::vect(bas_sample$sample), "EPSG:4326"), geom = "XY")
pts_df<-pts_df[,c("x","y")]
names(pts_df) <-  c( "lon", "lat")

#save plot
maps_path <- file.path(outputFolder, "maps_output.png")
ggplot2::ggsave(maps_output, filename= maps_path,
                height = 5, width = 10, units = "in" , dpi = 300, bg ="white")
biab_output("maps_output", maps_path)

#save output of selected points
pts_df_path<-file.path(outputFolder, "pts_selected_df.csv")
write.csv(pts_df, pts_df_path, row.names = FALSE )
biab_output("pts_df", pts_df_path)


#save shapefile of points
points_shape<-terra::project(terra::vect(bas_sample$sample), "EPSG:4326")
points_shape_path <- file.path(outputFolder, "points_shape.GeoJSON")
writeVector(points_shape, points_shape_path, overwrite=TRUE)
biab_output("points_shape", points_shape_path)
