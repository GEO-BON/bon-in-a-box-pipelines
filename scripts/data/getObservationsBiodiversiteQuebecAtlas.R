library(dplyr)
library(duckdb)
library(rjson)
setwd(outputFolder)
#Connect to parquet
atlas_con <- dbConnect(duckdb(),read_only=TRUE)
options(timeout=1000)
dbExecute(atlas_con, "SET temp_directory='/tmp/dbtmp';SET extension_directory='/tmp/dbtmp';")
dbExecute(atlas_con, "INSTALL httpfs;LOAD httpfs;")
setwd(outputFolder)

base_url<-'https://object-arbutus.cloud.computecanada.ca/bq-io/atlas/parquet/'
atlas_dates <- read.csv(paste0(base_url,'atlas_export_dates.csv'),header=FALSE, col.names=c('dates'))
dbdate <- tail(atlas_dates$dates,n=1)
file_name<-paste0(base_url,'atlas_public_',dbdate,".parquet")
dbExecute(atlas_con, paste0("CREATE VIEW atlas AS SELECT * FROM read_parquet('",file_name,"');"))


#Load inputs
input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)

if(!is.null(input$taxa)){
    taxa<-input$taxa
}else{
    output$error<-"Please specify taxa"
}
if(!is.null(input$bbox)){
    bbox <- input$boox
}else{
    bbox <- FALSE
}
if(!is.null(input$min_year)){
    min_year<- input$min_year
}else{
    min_year <- FALSE
}
if(!is.null(input$max_year)){
    max_year<- input$max_year
}else{
    max_year <- FALSE
}

#Build query
selq <-"SELECT *"
whereq <- paste0(" WHERE valid_scientific_name IN(",paste0("'",paste(taxa,collapse="','"),"'"),")")
filt <- 
if(length(input$bbox)>0){
  minx=input$bbox[1]
  maxx=input$bbox[3]
  miny=input$bbox[2]
  maxy=input$bbox[4]
  selq <- paste0(selq,", cast(longitude AS DOUBLE) as lng, cast(latitude AS DOUBLE) as lat ")
  whereq <- paste0(whereq,' AND lng >=',minx,' AND lat >= ',miny,' AND lng <= ',maxx,' AND lat <=',maxy)
}
if(min_year | max_year){
  selq <- paste0(selq,", cast(year_obs AS INTEGER) AS yr")
}
if(min_year){
  whereq <- paste0(whereq,' AND yr >=',min_year)
}
if(max_year){
  whereq <- paste0(whereq,' AND yr <=',max_year)
}
q<-paste0(selq,' FROM atlas ',whereq)
print(q)
data <- dbGetQuery(atlas_con, q)
data <- data[, !(names(data) %in% c("lat", "lng", "yr","geom","geom_bbox"))]
print(data)

outF <- file.path(outputFolder)
outFile <- paste0(outF,'/Observations.csv')

write.csv(data,outFile)

output <- list("observations_file" = outFile, "total_records" = nrow(data),"database_date" = dbdate)
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))