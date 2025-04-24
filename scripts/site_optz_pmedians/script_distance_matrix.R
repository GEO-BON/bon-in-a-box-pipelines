library(rjson)


#read inputs
input <- biab_inputs()  

# get environmental layers from BiaB form
# assumed chelsa layers in WGS84
# warning if layers are not WGS84
print("Calling environmental variable rasters")
predictors <- terra:: rast(c(input$rasters))
print(predictors)

print("Loading observtion locations / sampling sites and vectorizing them") ## need to call an external file
# or the sampling selection pipeline???? ask BiaB team 

locs_df <- read.csv(input$locations_csv) ######
print(locs_df)

locs <- terra::vect(locs_df, crs = "EPSG:4326")
locs<- terra::project(locs, predictors)

set.seed(1234)
print ("Scaling environmental variables")
env_ras_scaled <- terra::scale(predictors)

print(env_ras_scaled)


#extract the env values for each site for all layers 
print ("Extracting values of environmental variables for each locations")

values_occ <- terra::extract(env_ras_scaled, locs)
values_occ$ID<-NULL #eliminates the ID column from terra:extract
print(values_occ)
# produce env distance matrix (for locations)

#########
type <- "euclidean" # can make this a parameter in BiaB inputs ??
#########

print( paste("Creating env distance matrix using", type, "distances"))

env_matrix <- as.matrix(dist(values_occ, method= type))
str(env_matrix)



print( paste("Creating spatial distance matrix using", type, "distances"))

# create spatial distance matrix based on points (euclidean on WGS84 or projected???)
dist_matrix <- as.matrix(dist(locs_df, method="euclidean"))
str(dist_matrix)

print( paste("Scaling env and spatial matrices together" ))

# multiply matrices (why is this done on surdes? to somewhat combine them only?)
mdist <- env_matrix * dist_matrix


### how to ouput a matrix, what is the best way???  as a CSV or TSV?

##BiaB OUTPUTS

#save output of env dist
env_matrix_path<-file.path(outputFolder, "env_matrix.csv") 
write.csv(env_matrix, env_matrix_path, row.names = FALSE )
biab_output("env_matrix", env_matrix_path)

#save output of env dist
dist_matrix_path<-file.path(outputFolder, "dist_matrix.csv") 
write.csv(dist_matrix, dist_matrix_path , row.names = FALSE)
biab_output("dist_matrix", dist_matrix_path)

#save output of joint dist
mdist_path<-file.path(outputFolder, "mdist.csv") 
write.csv(mdist, mdist_path, row.names = FALSE )
biab_output("mdist", mdist_path)