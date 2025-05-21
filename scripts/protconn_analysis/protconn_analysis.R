# Script for analyzing ProtConn with the function

packagesList<-list("sf","terra", "dplyr", "ggrepel", "rjson", "Makurhini", "PROJ")

# Load libraries
lapply(packagesList, library, character.only = TRUE)  # Load libraries - packages

sf_use_s2(FALSE) # turn off spherical geometry

input <- biab_inputs() # Load input file

units::units_options(set_units_mode = "standard")
# Load study area shapefile
print("Loading polygons")
study_area <- st_read(input$study_area_polygon)
print("CRS:")
print(st_crs(study_area))
study_area <- st_transform(study_area, st_crs(input$crs))

#check if there is WDPA data
protected_areas <- input$protected_area_polygon[grepl("protected_areas_clean", input$protected_area_polygon)]

#check if there is user data
protected_areas_user <- input$protected_area_polygon[grepl("/userdata", input$protected_area_polygon)]

if (length(protected_areas_user) > 0 && length(protected_areas) > 0){
  print("Using both WDPA and User input")
  pa_input_type <- "Both"

} else if (length(protected_areas_user) > 0) {
  print("Only using user input data")
  pa_input_type <- "User input"

} else if (length(protected_areas) > 0){
  print("Using WDPA data")
  pa_input_type <- "WDPA"
} else {
  biab_error_stop("No files found: Please input or choose a study area")
}

### Load protected area shapefile
if(pa_input_type == "WDPA"| pa_input_type == "Both"){ # if using WDPA data, load that

  print(protected_areas)
  protected_areas <- st_read(protected_areas, type=3, promote_to_multi=FALSE) # input as polygons
  protected_areas <- st_transform(protected_areas, st_crs(input$crs))
  # fix date
  protected_areas$legal_status_updated_at <- lubridate::parse_date_time(protected_areas$legal_status_updated_at, orders=c("ymd", "mdy", "dmy", "y"))
  protected_areas$legal_status_updated_at <- lubridate::year(protected_areas$legal_status_updated_at)

  print("Protected area geometry:")
  print(unique(st_geometry_type(protected_areas)))
}


if(pa_input_type == "User input"| pa_input_type =="Both"){ # rename and parse date column
  protected_areas_user <- st_read(protected_areas_user, type=3, promote_to_multi=FALSE) # load
  print(protected_areas_user)

  # fix geometry and remove points
  protected_areas_user <- protected_areas_user[!st_geometry_type(protected_areas_user)%in% c("POINT","MULTIPOINT"),]
  # turning multipolygons to polygons
  if (any(st_geometry_type(protected_areas_user) %in% "MULTIPOLYGON")){
    print("Turning multipolygons into polygons")
    multi <- protected_areas_user[st_geometry_type(protected_areas_user)=="MULTIPOLYGON",]
    multi <- st_cast(multi, to="POLYGON", group_or_split=TRUE)
    poly <- protected_areas_user[st_geometry_type(protected_areas_user)=="POLYGON",]
    protected_areas_user <- rbind(poly, multi)
  }

  if(is.null(input$date_column)){
    biab_error_stop("Please specify a date column name for the protected areas file.")
  }
  protected_areas_user <- protected_areas_user %>% rename(legal_status_updated_at = input$date_column)
  protected_areas_user$legal_status_updated_at <- lubridate::parse_date_time(protected_areas_user$legal_status_updated_at, orders=c("ymd", "mdy", "dmy", "y"))
  protected_areas_user$legal_status_updated_at <- lubridate::year(protected_areas_user$legal_status_updated_at)
}

if(pa_input_type == "User input"){
  protected_areas <- protected_areas_user
}

if(pa_input_type == "Both"){

  if (!"geom" %in% names(protected_areas)) { # check that geom column exists
  biab_error_stop("Geometry column must be called 'geom'")
  }
  print("Combining user defined protected areas with WDPA data")
  protected_areas <- protected_areas[,c("legal_status_updated_at", "geom")]
  protected_areas_user <- protected_areas_user[,c("legal_status_updated_at", "geom")]

  protected_areas <- rbind(protected_areas, protected_areas_user)
}

print(nrow(protected_areas))

## Make function to get rid of overlapping geometries
dissolve_overlaps <- function (x) {

print("Combining overlapping geometries")
protected_areas_clean <- st_buffer(x, dist=10) # buffering polygons by 10 meters
intersections <- st_intersects(protected_areas_clean) # Identifying intersecting polygons

groups <- as.integer(igraph::components(graph = igraph::graph_from_adj_list(intersections))$membership) # Grouping intersecting polygons

x$group_id <- groups
print(x[x$group_id==1])

protected_areas_clean <- x %>%
  group_by(group_id) %>% filter(!group_id==1) %>%
  summarize(geom = st_union(geom), .groups = "drop") # COmbining intersecting polygons

return(protected_areas_clean)
}

############## CALCULATE PROTCONN ##################

print("Calculating ProtConn")
protected_areas <- protected_areas %>% filter(legal_status_updated_at <= input$years)
# Get rid of overlaps
protected_areas_simp <- dissolve_overlaps(protected_areas)

if(nrow(protected_areas_simp)<2){
biab_error_stop("Can't calculate ProtConn on one or less protected areas, please check input file.")
} 
print("Printing threshold")
print(input$distance_threshold)
protconn_result <- Makurhini::MK_ProtConn(
  nodes=protected_areas_simp,
  region=study_area,
  area_unit="m2",
  distance=list(type=input$distance_matrix_type),
  probability=0.5,
  transboundary=input$transboundary_distance,
  distance_thresholds=c(input$distance_threshold)
)
gc()

protconn_result <- as.data.frame(protconn_result)[c(2,3,4),c(3,4)]
protconn_result[is.na(protconn_result)] <- 0
print(protconn_result)

# Output protconn result
protconn_result_path <- file.path(outputFolder, "protconn_result.csv") # Define the file path for the 'val_wkt_path' output
write.csv(protconn_result, protconn_result_path, row.names = F ) # Write the 'val_wkt_path' output
biab_output("protconn_result", protconn_result_path)


result_plot <- ggplot2::ggplot(protconn_result) +
  geom_col(aes(y=Percentage, x=1, fill=`ProtConn indicator`)) +
  coord_polar(theta="y") +
  xlim(c(0, 1.5)) +
  geom_text(aes(y=Percentage, x=1, group=`ProtConn indicator`, label=paste0(round(Percentage, 2), "%")), position=position_stack(vjust=0.5))+
  scale_fill_manual(values=c("seagreen4", "seagreen1", "orchid4"))+
  theme_void() +
  theme(text=element_text(color="White"))

# output result plot
result_plot_path <- file.path(outputFolder, "result_plot.png") # save protconn result
ggsave(result_plot_path, result_plot, dpi=300, height=7, width=7)
biab_output("result_plot", result_plot_path)



print("Calculating ProtConn for three most common dispersal distances")
if(input$distance_threshold == 1000){ # skip if already ran in the original analysis
  protconn_result_1km <- protconn_result
  protconn_result_1km$distance <- "1 km"
} else {
protconn_result_1km <- Makurhini::MK_ProtConn(nodes=protected_areas_simp, region=study_area, area_unit="m2", distance=list(type=input$distance_matrix_type), probability=0.5,
transboundary=input$transboundary_distance, distance_thresholds=1000)
protconn_result_1km <- as.data.frame(protconn_result_1km)[c(2,3,4),c(3,4)]
protconn_result_1km[is.na(protconn_result_1km)] <- 0
protconn_result_1km$distance <- "1 km"
}
print("1km done")
print(protconn_result_1km)
gc()


if(input$distance_threshold == 10000){ # skip if already ran in the original analysis
  protconn_result_10km <- protconn_result
  protconn_result_10km$distance <- "10 km"
} else {
protconn_result_10km <- Makurhini::MK_ProtConn(nodes=protected_areas_simp, region=study_area, area_unit="m2", distance=list(type=input$distance_matrix_type), probability=0.5,
transboundary=input$transboundary_distance, distance_thresholds=10000)
protconn_result_10km <- as.data.frame(protconn_result_10km)[c(2,3,4),c(3,4)]
protconn_result_10km[is.na(protconn_result_10km)] <- 0
protconn_result_10km$distance <- "10 km"
}
print("10km done")
print(protconn_result_10km)
gc()

if(input$distance_threshold == 100000){ 
  protconn_result_100km <- protconn_result
  protconn_result_100km$distance <- "100 km"
} else {
protconn_result_100km <- Makurhini::MK_ProtConn(nodes=protected_areas_simp, region=study_area, area_unit="m2", distance=list(type=input$distance_matrix_type), probability=0.5,
transboundary=input$transboundary_distance, distance_thresholds=100000)
protconn_result_100km <- as.data.frame(protconn_result_100km)[c(2,3,4),c(3,4)]
protconn_result_100km[is.na(protconn_result_100km)] <- 0
protconn_result_100km$distance <- "100 km"
}
print("100km done")
print(protconn_result_100km)
results_preset <- rbind.data.frame(protconn_result_1km, protconn_result_10km, protconn_result_100km)
gc()

result_preset_plot <- ggplot2::ggplot(results_preset) +
  geom_col(aes(y=Percentage, x=1, fill=`ProtConn indicator`)) +
  coord_polar(theta="y") +
  xlim(c(0, 1.5)) +
  geom_text(aes(y=Percentage, x=1, group=`ProtConn indicator`, label=paste0(round(Percentage, 2), "%")), position=position_stack(vjust=0.5)) +
  scale_fill_manual(values=c("seagreen4", "seagreen1", "orchid4")) +
  facet_wrap(~distance) +
  theme_void() +
  theme(text=element_text(color="White"))

# output
result_plot_preset_path <- file.path(outputFolder, "result_preset_plot.png")
ggsave(filename=result_plot_preset_path, plot=result_preset_plot, dpi=300, height=8, width=12)
biab_output("result_preset_plot", result_plot_preset_path)



# Change in protection over time
# Sequence with start year by interval

years <- seq(from=input$start_year, to=input$years, by=input$year_int)
years <- c(years, input$years)
# assign all PAs with no date to the start date for plotting
for(i in 1:nrow(protected_areas)) {
  if(is.na(protected_areas$legal_status_updated_at[i])){
    print("fixing date")
    protected_areas$legal_status_updated_at[i] <- input$start_year
  }
}
print(protected_areas)
# Calculate ProtConn for each specified year
print("Calculating ProtConn time series")

protconn_ts_result <- list()

for (i in 1:length(years)) {
  print(years[i])
  protected_area_filt_yr <- protected_areas %>% dplyr::filter(legal_status_updated_at <= years[i])
  if((nrow(protected_area_filt_yr))<2) {
    print(paste("Not enough protected area data from", years, "beginning calculations at first year with data"))
    next
  } else {
    if (years[i]==input$years){
      protconn_result_yrs <- protconn_result
    } else {
    protected_area_filt_yr <- dissolve_overlaps(protected_areas_filt_yr)
    protconn_result_yrs <- Makurhini::MK_ProtConn(
      nodes=protected_area_filt_yr,
      region=study_area, area_unit="m2",
      distance=list(type=input$distance_matrix_type),
      probability=0.5,
      transboundary=input$transboundary_distance,
      distance_thresholds=c(input$distance_threshold)
    )
    protconn_result.df <- as.data.frame(protconn_result_yrs)[c(1,3,4),c(3,4)] %>% mutate(Year=years[i])
    gc()
    }
    print(protconn_result_yrs)
    protconn_ts_result[[i]] <- protconn_result.df
  }
}

print("Compiling time series")
result_yrs <- bind_rows(protconn_ts_result)
result_yrs[is.na(result_yrs)] <- 0
print(class(result_yrs))

result_yrs_path <- file.path(outputFolder, "result_yrs.csv") # save protconn result
write.csv(result_yrs, result_yrs_path)
biab_output("result_yrs", result_yrs_path)

xint <- min(result_yrs$Year) + 25
print(result_yrs)
result_yrs_plot <- ggplot(result_yrs, aes(x=Year, y=Percentage, group=`ProtConn indicator`, shape=`ProtConn indicator`, color=`ProtConn indicator`))+
  geom_point() +
  geom_line() +
  labs(y="Percent area", x="Year") +
  geom_hline(yintercept=30, lty=2) +
  annotate("text", x=xint, y=31, label="Kunming-Montreal target") +
  geom_line() +
  theme_classic()

result_yrs_plot_path <- file.path(outputFolder, "result_plot_yrs.png") # save protconn result with dispersal presets
ggsave(result_yrs_plot_path, result_yrs_plot)
biab_output("result_yrs_plot", result_yrs_plot_path)



