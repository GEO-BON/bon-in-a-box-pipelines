library(sf)
library(dplyr)
library(ggplot2)
library(forcats)
library(units)
sf_use_s2(FALSE)
input <- biab_inputs()

iucn_categories <- function(cat){
  iu <- data.frame(
  Category = c("Ia", "Ib", "II", "III", "IV", "V", "VI", "OECM", "Not Applicable", "Not Reported"),
  Label = c(
    "Strict Nature Reserve",
    "Wilderness Area",
    "National Park",
    "Natural Monument or Feature",
    "Habitat/Species Management Area",
    "Protected Landscape/Seascape",
    "Protected Area with Sustainable Use of Natural Resources",
    "Other Effective Area-Based Conservation Measure",
    "Not Applicable",
    "Not Reported"
  ),
  Description = c(
    "Protected area managed mainly for science.",
    "Protected area managed mainly for wilderness protection.",
    "Protected area managed mainly for ecosystem protection and recreation.",
    "Protected area managed mainly for conservation of specific natural features.",
    "Protected area managed mainly for conservation through management intervention.",
    "Protected area managed mainly for conservation of landscape/seascape and recreation.",
    "Protected area managed mainly for the sustainable use of natural ecosystems.",
    "A geographically defined area, other than a Protected Area, which is governed and managed in ways that achieve positive and sustained long-term outcomes for the *in situ* conservation of biodiversity.",
    "Not applicable",
    "Not reported"
  ),
  Priority = c(1,2,3,4,5,7,6,8,9,10),
  stringsAsFactors = FALSE
  )
  return(iu[iu$Category==cat,])
}



start_year <- input$start_year
year_int <- input$year_int
crs <- input$crs
study_area <- input$study_area_polygon
protected_areas <- input$protected_area_polygon
date_column_name <- input$date_column_name
if(date_column_name == "" || is.null(date_column_name)){
  date_column_name <- "legal_status_updated_at"
}

pa <- st_buffer(st_make_valid(st_read(protected_areas)) |> st_transform(crs),0)
study_area <- st_make_valid(st_read(study_area)) |> st_transform(crs)
total_area <- st_area(study_area) |> drop_units()

pa$iucn_cat <- factor(unlist(lapply(pa$iucn_category,
    FUN=function(x){j=fromJSON(gsub("'",'"',x));return(j$name)})),
    levels=c('Ia','Ib','II','III','IV','V','VI','OECM','Not Applicable','Not Reported'))

pa$year <- as.numeric(format(as.Date(pa[[date_column_name]], format = "%d/%m/%Y"), "%Y"))
pa$type <- ifelse(pa$marine,'Marine','Terrestrial')
pa$priority <- unlist(lapply(pa$iucn_cat,FUN=function(x){iucn_categories(x)$Priority}))

pa <- pa[!is.na(pa$year),]
# Put all PAs before start year to start year or plot
pa[pa$year < start_year,'year'] <- start_year

pa_iucn_type <- pa |> 
  group_by(type, year, iucn_cat, priority) |>
  summarize(area=sum(st_area(geom))) |>
  ungroup() |> arrange(type, year, priority)

# For each time step, type and year, remove lower priority PAs that overlap with higher priority PAs
for (r in 1:nrow(pa_iucn_type)){
  row <- pa_iucn_type[r,]
  if(row$priority==1){
    tt <- row
  }else{
    tt <- row |> st_difference(st_union(pa_iucn_type |> filter(priority < row$priority & year >= row$year)))
  }
  if(r==1){
    pa_iucn_tmp <- tt
  }else{
    pa_iucn_tmp <- rbind(pa_iucn_tmp,tt)
  }
  print(r)
}
pa_iucn_tmp$corrected_area <- st_area(pa_iucn_tmp)

pa_iucn_corr <- pa_iucn_tmp |> group_by(type, year, iucn_cat) |> 
  mutate(cum_area=sum(corrected_area)) |> drop_units()

pa_iucn_corr$iucn_cat = factor(pa_iucn_corr$iucn_cat,levels=c('Ia','Ib','II','III','IV','V','VI','OECM','Not Applicable','Not Reported'))

#Total area per type over time
pa_type_yrs_table <- pa_iucn_corr |> group_by(type, year) |> 
           summarize(cum_area=sum(cum_area)) |> ungroup() |> arrange(type, year)

type_yrs_table_path <- file.path(outputFolder, "type_yrs_table.csv") 

write.csv(pa_type_yrs_table |> st_drop_geometry(), type_yrs_table_path)
biab_output("type_yrs_table", type_yrs_table_path)


plot_type <- ggplot(pa_type_yrs_table |> 
         arrange(type, year), aes(x=year, y=cumsum(cum_area/(10000^2)), color=type)) + 
  geom_line() + theme_minimal() + scale_color_manual(values=c('blue','darkgreen')) +
  labs(y=bquote('Area '(km^2)), x="Year",color='Type')

plot_type_path <- file.path(outputFolder, paste0("plot_PAs_by_marine_terrestrial.png"))

ggsave(plot_type_path, plot_type, width=18, height=12, units='cm')
biab_output("type_yrs_plot", plot_type_path)

#TOTAL AREA for terrestrial PAs over time by IUCN category 

pa_iucn_type <- pa |> st_intersection(study_area) |> 
  filter(type=='Terrestrial') |> 
  group_by(type, year, iucn_cat, priority) |>
  summarize(area=sum(st_area(geom))) |>
  ungroup() |> arrange(type, year, priority)

pa_vec_path <- file.path(outputFolder, "protected_areas_by_iucn_type_years.gpkg")
st_write(pa_iucn_type, pa_vec_path, delete_dsn=TRUE)
biab_output("protected_areas", pa_vec_path)



# For each time step, type and year, remove lower priority PAs that overlap with higher priority PAs
for (r in 1:nrow(pa_iucn_type)){
  row <- pa_iucn_type[r,]
  if(row$priority==1){
    tt <- row
  }else{
    tt <- row |> st_difference(st_union(pa_iucn_type |> filter(priority < row$priority & year >= row$year)))
  }
  if(r==1){
    pa_iucn_tmp <- tt
  }else{
    pa_iucn_tmp <- rbind(pa_iucn_tmp,tt)
  }
  print(r)
}
pa_iucn_tmp$corrected_area <- st_area(pa_iucn_tmp)

pa_iucn_corr <- pa_iucn_tmp |> group_by(type, year, iucn_cat) |> 
  mutate(cum_area=sum(corrected_area)) |> drop_units()

pa_iucn_corr$iucn_cat = factor(pa_iucn_corr$iucn_cat,levels=c('Ia','Ib','II','III','IV','V','VI','OECM','Not Applicable','Not Reported'))



pa_iucn_yrs_table <- pa_iucn_corr |> 
  filter(type == 'Terrestrial') |> 
  group_by(iucn_cat, year) |>
  arrange(iucn_cat, year) |> 
  summarize(cum_area=sum(cum_area)) |> 
  mutate(cum_area2 = cumsum(cum_area)) |>
  ungroup() |> drop_units()

iucn_yrs_table_path <- file.path(outputFolder, "iucn_yrs_table.csv")

write.csv(pa_iucn_yrs_table |> select(-cum_area)|> st_drop_geometry(), iucn_yrs_table_path)
biab_output("terrestrial_iucn_yrs_table", iucn_yrs_table_path)

#TOTAL AREA FOR ALL PAs over time
pa_total_years_table <- pa_iucn_corr |> filter(type=='Terrestrial') |> group_by(year) |> 
  arrange(year) |>
  summarize(cum_area = sum(cum_area)) |> 
  mutate(cum_area2 = cumsum(cum_area)) |>
  mutate(percentage = 100*cum_area2/total_area) |>
  ungroup() |> drop_units()
total_years_table_path <- file.path(outputFolder, "total_yrs_table.csv")
write.csv(pa_total_years_table |> st_drop_geometry(), total_years_table_path)
biab_output("terrestrial_total_yrs_table", total_years_table_path)

#Area and percentage per IUCN category over time for terrestrial PAs
plot_iucn_cat <- ggplot() +
  geom_line(data=pa_iucn_yrs_table, aes(x=year, y=cum_area2/(1000^2), color=iucn_cat)) +
  geom_line(data=pa_total_years_table, aes(x=year, y=cum_area2/(1000^2))) +
  geom_text(aes(x=max(pa_total_years_table$year), 
                y=max(pa_total_years_table$cum_area2/(1000^2)), 
                label=paste0(round(max(pa_total_years_table$percentage),1),'%')), hjust = 1, size = 5) +
  theme_minimal() +
  scale_y_continuous("Area (km²)",
                     sec.axis = sec_axis(~ 100* . / (total_area/(1000^2)), name = "Percentage of region")) +
  labs(y=bquote('Area '(km^2)), x="Year",color='IUCN category') + scale_color_brewer(palette = "Paired")

plot_iucn_cat_path <- file.path(outputFolder, paste0("plot_PAs_by_IUCN_categories.png"))

ggsave(plot_iucn_cat_path, plot_iucn_cat, width=18, height=12, units='cm')
biab_output("terrestrial_iucn_yrs_plot", plot_iucn_cat_path)

