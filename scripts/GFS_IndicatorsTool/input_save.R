## Environment variables available
# Script location can be used to access other scripts
print(Sys.getenv("SCRIPT_LOCATION"))

## Install required packages
packages <- c("rjson")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

library("rjson")
input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)

input_list=list(input$yoi, input$nenc, input$title, input$popdensity, input$speciesname, input$bbox, input$buffer, input$popdistance, input$startyear, input$endyear, input$username, input$useremail, input$country, input$LCtype)

## Outputing result to JSON
# notice that the warning string is not part of the yml spec, so it cannot be used by other scripts, but will still be displayed.
output <- list("list"=input_list
                )

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))

# (If we get a problem with encoding, we could use utf-8 library to clean the output, since the server reads it as utf-8)