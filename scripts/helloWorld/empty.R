# Script location can be used to access other scripts source
#Sys.getenv("SCRIPT_LOCATION")

## Receiving arguments from input.json.
## outputFolder is already defined by server
library("rjson")
input <- biab_inputs()

## Parameter validation, use biab_error_stop("message") if something is wrong.
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
    "<OUTPUT NAME>", <OUTPUT FILE PATH>
) 
                
