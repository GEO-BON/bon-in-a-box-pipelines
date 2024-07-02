# Load required packages - libraries to run the script ####

# Install necessary libraries - packages  
packagesPrev<- installed.packages()[,"Package"] # Check and get a list of installed packages in this machine and R version
packagesNeed<- c("magrittr", "data.table", "terra", "raster", "sf", "pbapply", "this.path", "rjson", "tools", "unmarked", "reshape2", "Rcpp" , "RcppEigen", "RcppParallel", "RcppNumerical", "secr", "camtrapR") # Define the list of required packages to run the script
new.packages <- packagesNeed[!(packagesNeed %in% packagesPrev)];



# Load libraries
packagesList<-list("magrittr", "camtrapR") # Explicitly list the required packages throughout the entire routine. Explicitly listing the required packages throughout the routine ensures that only the necessary packages are listed. Unlike 'packagesNeed', this list includes packages with functions that cannot be directly called using the '::' syntax. By using '::', specific functions or objects from a package can be accessed directly without loading the entire package. Loading an entire package involves loading all the functions and objects 
lapply(packagesList, library, character.only = TRUE)  # Load libraries - packages  

print("a")



## Write results ####
umf_matrix_path<- file.path(outputFolder, "umf_matrix.csv") # Define the file path for the 'val_wkt_path' output
write.csv(data.frame(), umf_matrix_path, row.names = T ) # Write the 'val_wkt_path' output


#### Outputing result to JSON ####
output<- list(umf_matrix= umf_matrix_path)

# Write the output list to the 'output.json' file in JSON format
setwd(outputFolder)
jsonlite::write_json(output, "output.json", auto_unbox = TRUE, pretty = TRUE)


