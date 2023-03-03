## Install required packages
packages <- c("rjson")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

library("rjson")
input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)


for (x in 1:input$end) {
  Sys.sleep(1)
  print(x)
} 


## Outputing result to JSON
output <- list("end" = input$end) 
                
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))