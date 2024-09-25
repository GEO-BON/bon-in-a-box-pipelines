packages <- c("rjson", "readr")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

library(rjson)
library(readr)

input <- fromJSON(file=file.path(outputFolder, "input.json"))


pointcount<-input$points
pdg_table<-read.csv(input$pdg_table)

if(is.null(input$pop_density)){
  pop_density<-pointcount/sum(pdg_table[1])
}else(pop_density<-input$pop_density)
print(pop_density)
ne_ncratio<-input$ne_ncratio

Ne<-pdg_table[22]*pop_density*ne_ncratio
Ne500<-Ne>=500
ne_ratio<-sum(Ne500)/length(Ne[,1])

PM<-pdg_table[22]!=0
pm_ratio<-sum(PM)/length(PM)

ne_data<-data.frame(c(1:length(Ne[,1])),Ne, Ne500, !PM)
colnames(ne_data)<-c("Population ID","Ne","Ne>=500","extinct")
path<- file.path(outputFolder, "ne_data.csv")
write.csv(ne_data, path)

## Outputing result to JSON
output <- list("ne_data"=path, "ne_ratio"=ne_ratio, "pm_ratio"=pm_ratio)

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))