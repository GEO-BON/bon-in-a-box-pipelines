# Environment variables available
print(Sys.getenv("SCRIPT_LOCATION"))

# Install missing packages
packages <- c("rjson")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

# Receiving args
args <- commandArgs(trailingOnly=TRUE)
outputFolder <- args[1] # Arg 1 is always the output folder
cat(args, sep = "\n")

# Script body
example_file = file.path(outputFolder, "hello_world.txt")
file.create(example_file)

# Outputing result to JSON
output <- list(presence = example_file, 
                uncertainty = "map2.tiff")
                
library("rjson")
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))

# (If we get a problem with encoding, we could use utf-8 library to clean the output, since the server reads it as utf-8)