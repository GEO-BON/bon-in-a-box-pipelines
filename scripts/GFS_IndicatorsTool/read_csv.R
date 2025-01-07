library("rjson")


input <- fromJSON(file=file.path(outputFolder, "input.json"))

print(input)

tsv_json <-input$csv

##### Parse json text

### remove square brackets
tsv_json = substr(tsv_json, 3, nchar(tsv_json)-2)

### split lines
tsv_lines = strsplit(tsv_json, '\\), \\(')[[1]]

### convet to table
tsv_tab = do.call(rbind, strsplit(tsv_lines, ', '))

### convert to data.frame, set header
tsv_df = data.frame(tsv_tab[-1,])
colnames(tsv_df) = tsv_tab[1,]

colnames(tsv_df)[colnames(tsv_df)=="'decimal_latitude'"] = 'decimal_latitude'
colnames(tsv_df)[colnames(tsv_df)=="'decimal_longitude'"] = 'decimal_longitude'

### set coordinates as numeric
tsv_df$decimal_latitude = as.numeric(tsv_df$decimal_latitude)
tsv_df$decimal_longitude = as.numeric(tsv_df$decimal_longitude)

### set output path
tsv_out<-file.path(outputFolder, "species_obs.tsv")


### save output
write.table(tsv_df, file=tsv_out, sep='\t', quote=F, row.names = F, col.names = T)




### return output
output <- list("csv_out"=tsv_out)
print(output)

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))