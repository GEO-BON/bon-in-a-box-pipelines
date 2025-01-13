## Environment variables available
# Script location can be used to access other scripts
print(Sys.getenv("SCRIPT_LOCATION"))

## Install required packages
packages <- c("rjson", "sf")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

library("rjson")
library("sf")
input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)

print(read.csv(input$poparea, sep="\t"))

write(as.character(read.csv(input$poparea, sep="\t")), file=file.path(outputFolder, "population_area.tsv"))
write(as.character(read.csv(input$popsize, sep="\t")), file=file.path(outputFolder, "population_size.tsv"))
write(as.character(st_read(input$geojson)), file=file.path(outputFolder, "pop_poly.geojson"))
current_folder <- input$coverchange
new_folder <- file.path(outputFolder, "coverchange")
list_of_files <- list.files(current_folder) 
dir.create(new_folder, showWarnings = FALSE)
file.copy(file.path(current_folder, list_of_files), new_folder, overwrite = TRUE)

## Outputing result to JSON
# notice that the warning string is not part of the yml spec, so it cannot be used by other scripts, but will still be displayed.
output <- list("list"=file.path(outputFolder)
                )

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))

# (If we get a problem with encoding, we could use utf-8 library to clean the output, since the server reads it as utf-8)