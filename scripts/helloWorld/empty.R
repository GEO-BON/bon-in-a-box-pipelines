# Script location can be used to access other scripts source
#Sys.getenv("SCRIPT_LOCATION")

## Install required packages
packages <- c("rjson")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

## Receiving arguments from input.json.
## outputFolder is already defined by server
library("rjson")
input <- fromJSON(file=file.path(outputFolder, "input.json"))

## Parameter validation
<YOUR VALIDATION HERE>

## Script body
<YOUR CODE HERE>

## Outputing result to JSON
output <- list(
    # Add your outputs here "key" = "value"
    # The output keys correspond to those described in the yml file.
    <YOUR OUTPUTS HERE>
    #"error" = "Some error", # halt the pipeline
    #"warning" = "Some warning", # display a warning without halting the pipeline
) 
                
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))