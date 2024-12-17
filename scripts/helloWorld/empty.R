# Script location can be used to access other scripts source
#Sys.getenv("SCRIPT_LOCATION")

## Install required packages
packages <- c("rjson")

## Receiving arguments from input.json.
## outputFolder is already defined by server
library("rjson")
input <- biab_inputs()

## Parameter validation
<YOUR VALIDATION HERE>

## Script body
<YOUR CODE HERE>

## Error
if (<SOME CONDITION>){
    biab_error_stop("ERROR MESSAGE")
}

## Warning
if (<SOME CONDITION>){
    biab_warning("WARNING MESSAGE")
}

## Outputing result to JSON
biab_output(
    # Add your outputs here "key" = "value"
    # The output keys correspond to those described in the yml file.
    <YOUR OUTPUTS HERE>
    #"error" = "Some error", # halt the pipeline
    #"warning" = "Some warning", # display a warning without halting the pipeline
) 
                
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))