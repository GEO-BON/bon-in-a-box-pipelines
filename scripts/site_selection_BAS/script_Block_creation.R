library(rjson)
library(terra)
library(ggplot2)
library(tidyterra)
library(cowplot)

#read inputs
input <- biab_inputs()  

# get environmental layers from BiaB form
# assumed chelsa layers in WGS84
# warning if layers are not WGS84
print("Calling environmental variable rasters")
variables <- terra:: rast(c(input$rasters))
print(variables)

print("Calling country shape polygon")
map_shape <-terra::vect(input$country_polygon)
print(map_shape)

#agregate for testing... make the call later about this with BiaB team
print("Aggregating to 10km pixel")

variables <- terra::aggregate(variables, 10,  fun="mean")

print("Masking aggregated raster stack of env variables")

variables <- terra::mask(variables, terra::project(map_shape, terra::crs(variables)))
print(variables)

crs_working <- terra::crs(variables)

type_analysis <-"PCA" #as.character(input$analysis_type)

print("Performing PCA on environmental variables")
if (type_analysis == "PCA") {
  
  #go the terra route for PCA
  
  pca_vars<-terra::princomp(variables, cor = TRUE, fix_sign = TRUE
  ) #cor true equals scaled
  
  summary_PCA <- summary(pca_vars)
  
  PCA_rast <- terra::predict(variables, pca_vars, index = 1:2)
  var1<-terra::values(PCA_rast$Comp.1)
  var2<-terra::values(PCA_rast$Comp.2)
  pca_summary<-summary(pca_vars)
  print(pca_summary)
  pca_importance <- function(x) {
    vars <- x$sdev^2
    vars <- vars/sum(vars)
    rbind(`Standard deviation` = x$sdev, `Proportion of Variance` = vars, 
          `Cumulative Proportion` = cumsum(vars))
  }
  
  pca_summary_df<-as.data.frame(pca_importance(pca_summary))
  
}else{
  var1<-terra::values(variables[[1]])
  var2<-terra::values(variables[[2]])
}

############################################################
#MAKE BLOCKS, from biosurvey's code     
############################################################
#define columns and rows
print("Defining blocks based on PCA")
n_cols<- as.numeric(input$n_cols)
n_rows<- as.numeric(input$n_rows)
#from make blocks function in biosurvey  
print(n_cols)
class(n_cols)
print("Get parameters for blocks")
#tweaked to only call PCA, think about changing back to variable (either pca or raw var)
xrange <- range(var1, na.rm = TRUE)#data[, variable_1]
xinter <- diff(xrange) / n_cols
yrange <- range(var2, na.rm = TRUE)#data[, variable_2]
yinter <- diff(yrange) / n_rows
print(xrange)
print(xinter)
print("Produce sequence of grid")
xlb <- seq(xrange[1], xrange[2], xinter)
xlb[length(xlb)] <- xrange[2]
ylb <- seq(yrange[1], yrange[2], yinter)
ylb[length(ylb)] <- yrange[2]

# assign blocks function from biosurvey

print("Building temporary df of PCA1 and 2")

#check if this is redundant later!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
data <- data.frame(variable_1 = var1, 
                   variable_2 = var2)
variable_1<-names(data)[1]
variable_2<-names(data)[2]

## Blocks of equal area
print("Start block definition")
all_cls <- lapply(1:(length(xlb) - 1), function(x) {
  ## x-axis
  if(x == 1){
    x1 <- data[, variable_1] >= xlb[x]
  } else {
    x1 <- data[, variable_1] > xlb[x]
  }
  xid <- which(x1 & data[, variable_1] <= xlb[(x + 1)])
  if (length(xid) > 0) {
    pd <- data[xid, ]
    pd <- cbind(pd, NA)
    if (nrow(pd) > 0) {
      ## y-axis
      for (y in 1:(length(ylb) - 1)) {
        if(y == 1) {
          y1 <- pd[, variable_2] >= ylb[y]
        } else {
          y1 <- pd[, variable_2] > ylb[y]
        }
        yid <- which(y1 & pd[, variable_2] <= ylb[(y + 1)])
        nb <- ifelse(x == 1, y, (x * length(ylb)) + y)
        pd[yid, ncol(pd)] <- rep(nb, length(yid))
      }
    }
    return(pd)
  } else {
    return(data[0, ])
  }
})

# Finishing assigning
all_cls <- do.call(rbind, all_cls)
colnames(all_cls)[ncol(all_cls)] <- "Block"
all_cls <- all_cls[order(all_cls[, "Block"]), ]
unique(all_cls$Block)


id <- paste(data[, 1], data[, 2])
all_cls <- all_cls[match(id, paste(all_cls[, 1], all_cls[, 2])), ]
other_args <- list(arguments = list(variable_1 = variable_1,
                                    variable_2 = variable_2))
attributes(all_cls) <- c(attributes(all_cls), other_args)


df_vars<-terra::as.data.frame(PCA_rast[[1:2]], xy=TRUE, na.rm = FALSE)
df_vars$id<-paste0(df_vars$Comp.1, df_vars$Comp.2)

all_cls$id<-paste0(all_cls[, 1], all_cls[, 2])


merged_df<-merge(df_vars[complete.cases(df_vars[, 3]),], all_cls[complete.cases(all_cls[, 1]),], by.x="id", by.y ="id" )

print("Rasterizing PCA blocks")
rast_blocks<-terra::rast(merged_df[,c("x", "y", "Block")],  type="xyz", crs = crs_working)
print(rast_blocks)
#terra::plot(rast_blocks)


#plotting blocks 
set.seed(1)
colors_vect<-(sample( grDevices::colors()[grep('gr(a|e)y', 
                                               grDevices::colors(), 
                                               invert = T)], 
                      length(unique(merged_df[,c("x", "y", "Block")]$Block)) )  )

print("Plotting blocks in environmental space")
#produce env space blocks plot
p<-ggplot2::ggplot()+
  ggplot2::geom_point(data = all_cls, 
                      ggplot2::aes(x=Comp.1, 
                                   y = Comp.2, 
                                   colour =as.factor(Block)) )+
  ggplot2::scale_color_manual(values =colors_vect)+
  ggplot2::theme_bw()+
  ggplot2::theme(legend.position = "none")

#produce map of env block in geographical space
# its easier to define the colours with the df and geom_raster than with a terra rast
print(
summary(merged_df[,c("x", "y", "Block")])
)

print("Plotting blocks in geographic space") #NEED TO IMPROVE FOR PROJECTED CRS
q<-ggplot2::ggplot()+
  tidyterra::geom_spatvector(data= terra::project(map_shape, rast_blocks))+
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
                 )
  

blocks_plot <- cowplot::plot_grid(q, p, nrow=1)

#save plot
plot_blocks_map_path <- file.path(outputFolder, "blocks_plot.png") 
ggplot2::ggsave(blocks_plot, filename= plot_blocks_map_path,
                height = 5, width = 10, units = "in" , dpi = 300, bg ="white")
biab_output("blocks_plot", plot_blocks_map_path)

#save terra raster as well for BAS spbal
raster_blocks_path<-file.path(outputFolder, "raster_blocks.tif") 
terra::writeRaster(rast_blocks,raster_blocks_path )
biab_output("rast_blocks",raster_blocks_path)
#save output of PCA to check
pca_summary_path<-file.path(outputFolder, "pca_Summary.csv") 
write.csv(pca_summary_df, pca_summary_path )
biab_output("pca_summary_df", pca_summary_path)