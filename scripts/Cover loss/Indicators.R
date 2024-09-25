packages <- c("rjson", "readr")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

library(rjson)
library(readr)

input <- fromJSON(file=file.path(outputFolder, "input.json"))


pointcount<-input$points
PDG.TABLE<-read.csv(input$PDG.TABLE)

if(is.null(input$popdensity)){
  popdensity<-pointcount/sum(PDG.TABLE[1])
}else(popdensity<-input$popdensity)
print(popdensity)
ne_ncratio<-input$ne_ncratio

Ne<-PDG.TABLE[22]*popdensity*ne_ncratio
Ne500<-Ne>=500
Neratio<-sum(Ne500)/length(Ne[,1])

PM<-PDG.TABLE[22]!=0
PMratio<-sum(PM)/length(PM)

Nedata<-data.frame(c(1:length(Ne[,1])),Ne, Ne500, !PM)
colnames(Nedata)<-c("Population ID","Ne","Ne>=500","extinct")
path<- file.path(outputFolder, "Nedata.csv")
write.csv(Nedata, path)

## Outputing result to JSON
output <- list("Nedata"=path, "Neratio"=Neratio, "PMratio"=PMratio)

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))