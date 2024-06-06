#### Load required packages - libraries to run the script ####

# Install necessary libraries - packages  
packagesPrev<- installed.packages()[,"Package"] # Check and get a list of installed packages in this machine and R version
packagesNeed<- list("dplyr", "fields", "gridExtra","lubridate", "mccf1", "ranger",
                    "readr", "scam", "sf", "terra", "tidyr", "ebirdst","yaml", "precrec", "PresenceAbsence") # Define the list of required packages to run the script
lapply(packagesNeed, function(x) {   if ( ! x %in% packagesPrev ) { install.packages(x, force=T)}    }) # Check and install required packages that are not previously installed

# Load libraries
packagesList<-list("dplyr", "fields", "gridExtra","lubridate", "mccf1", "ranger",
                   "readr", "scam", "sf", "terra", "tidyr", "ebirdst","yaml", "PresenceAbsence") # Explicitly list the required packages throughout the entire routine. Explicitly listing the required packages throughout the routine ensures that only the necessary packages are listed. Unlike 'packagesNeed', this list includes packages with functions that cannot be directly called using the '::' syntax. By using '::', specific functions or objects from a package can be accessed directly without loading the entire package. Loading an entire package involves loading all the functions and objects 
lapply(packagesList, library, character.only = TRUE)  # Load libraries - packages  


#### Set environment variables ####

Sys.setenv(outputFolder = "/path/to/output/folder")

# Option 2: Recommended for debugging purposes to be used as a testing environment. This is designed to facilitate script testing and correction
if ( (!exists("outputFolder"))  ) {
  outputFolder<- {x<- this.path::this.path();  file_prev<-  paste0(gsub("/scripts.*", "/output", x), gsub("^.*/scripts", "", x)  ); options<- tools::file_path_sans_ext(file_prev) %>% {c(., paste0(., ".R"), paste0(., "_R"))}; folder_out<- options %>% {.[file.exists(.)]} %>% {.[which.max(sapply(., function(info) file.info(info)$mtime))]}; folder_final<- list.files(folder_out, full.names = T) %>% {.[which.max(sapply(., function(info) file.info(info)$mtime))]} }
}

input <- rjson::fromJSON(file=file.path(outputFolder, "input.json")) # Load input file

# This section adjusts the input values based on specific conditions to rectify and prevent errors in the input paths
input<- lapply(input, function(x) { if (!is.null(x) && length(x) > 0 && grepl("/", x) && !grepl("http://", x)  ) { 
  sub("/output/.*", "/output", outputFolder) %>% dirname() %>%  file.path(x) %>% {gsub("//+", "/", .)}  } else{x} }) 



####  Script body ####
# Load data ----
checklists_env <- read_csv(input$checklists)


# prediction grid
pred_grid <- read_csv(input$pred_grid)
# raster template for the grid
r <- rast(input$r)
# get the coordinate reference system of the prediction grid
crs <- st_crs(r)






# create empty lists to iterate over and save results
predictions <- list(); mcc_f1_summary <- list()
er_ppms <- list(); count_abd_ppms <- list()

for(i in 1:input$iters){
# split checklists into 20/80 test/train
checklists_env_split <- checklists_env
checklists_env_split$type <- if_else(runif(nrow(checklists_env_split)) <= 0.8, "train", "test")


# Spatiotemporal subsampling ----
# sample one checklist per 3km x 3km x 1 week grid for each year
# sample detection/non-detection independently
checklists_ss <- grid_sample_stratified(checklists_env_split,
                                        obs_column = "species_observed",
                                        sample_by = "type")

# Encounter rate ----
# filter to training data, select only the columns to be used in the model
checklists_train <- checklists_ss |>
  filter(type == "train") |>
  dplyr::select(species_observed, observation_count,
         year, day_of_year, hours_of_day,
         effort_hours, effort_distance_km, effort_speed_kmph,
         number_observers,
         starts_with("pland_"),
         starts_with("ed_"),
         starts_with("elevation_"))

# calculate detection frequency
detection_freq <- mean(checklists_train$species_observed)

# train a balanced random forest to classify detection/non-detection
# remove observation_count prior to training model
train_er <- dplyr::select(checklists_train, -observation_count)
er_model <- ranger(formula =  as.factor(species_observed) ~ .,
                   data = train_er,
                   importance = "impurity",
                   probability = TRUE,
                   replace = TRUE,
                   sample.fraction = c(detection_freq, detection_freq))


# Calibration ----
# predicted encounter rate based on out of bag samples
er_pred <- er_model$predictions[, 2]
# observed detection, converted back from factor
det_obs <- as.integer(checklists_train$species_observed)
# construct a data frame to train the scam model
obs_pred <- data.frame(obs = det_obs, pred = er_pred)

# train calibration model
calibration_model <- scam(obs ~ s(pred, k = 6, bs = "mpi"),
                          gamma = 2,
                          data = obs_pred)

# Thresholding ----
# mcc and fscore calculation for various thresholds
mcc_f1 <- mccf1(
  # observed detection/non-detection
  response = obs_pred$obs,
  # predicted encounter rate from random forest
  predictor = obs_pred$pred)
# identify best threshold
mcc_f1_summary[[i]] <- invisible(summary(mcc_f1))
threshold <- mcc_f1_summary[[i]]$best_threshold[1]


# Prediction ----
# add standardized effort covariates to prediction grid
# 6:30am
# 2 km, 1 hour traveling checklist with 1 observer
pred_grid_eff <- pred_grid |>
  mutate(observation_date = min(checklists_env$observation_date) + (max(checklists_env$observation_date) - min(checklists_env$observation_date))/2,
         year = year(observation_date),
         day_of_year = yday(observation_date),
         hours_of_day = 6.5,
         effort_distance_km = 2,
         effort_hours = 1,
         effort_speed_kmph = 2,
         number_observers = 1)

# estimate encounter rate
pred_er <- predict(er_model, data = pred_grid_eff, type = "response")
pred_er <- pred_er$predictions[, 2]

# define range-boundary
pred_binary <- as.integer(pred_er > threshold)

# apply calibration
pred_er_cal <- predict(calibration_model,
                       data.frame(pred = pred_er),
                       type = "response") |>
  as.numeric()

# constrain to 0-1
pred_er_cal[pred_er_cal < 0] <- 0
pred_er_cal[pred_er_cal > 1] <- 1

# combine predictions with coordinates from prediction grid
predictions[[i]] <- data.frame(cell_id = pred_grid_eff$cell_id,
                          x = pred_grid_eff$x,
                          y = pred_grid_eff$y,
                          in_range = pred_binary,
                          encounter_rate = pred_er_cal)



# Count model ----
# subset to only observed or predicted detections
train_count <- checklists_train
train_count$pred_er <- er_model$predictions[, 2]
train_count <- train_count |>
  filter(!is.na(observation_count),
         observation_count > 0 | pred_er > threshold) |>
  dplyr::select(-species_observed, -pred_er)

# add predicted encounter rate as an additional covariate
predicted_er <- predict(er_model, data = train_count, type = "response")
predicted_er <- predicted_er$predictions[, 2]
train_count$predicted_er <- predicted_er

# train a random forest to estimate expected count
count_model <- ranger(formula = observation_count ~ .,
                      data = train_count,
                      importance = "impurity",
                      replace = TRUE)


# Prediction ----
# add predicted encounter rate required for count estimates
pred_grid_eff$predicted_er <- pred_er
# estimate count
pred_count <- predict(count_model, data = pred_grid_eff, type = "response")
pred_count <- pred_count$predictions
# combine with all other predictions
predictions[[i]]$count <- pred_count
# relative abundance = encounter_rate * count
predictions[[i]]$abundance <- predictions[[i]]$encounter_rate * predictions[[i]]$count
# density proxy - proportion of population in region of interest
predictions[[i]]$prop_pop <- predictions[[i]]$abundance / sum(predictions[[i]]$abundance)


# Assessment ----
# Predict to test data
# get the test set held out from training
# only consider checklists with counts
checklists_test <- checklists_ss |>
  filter(type == "test", !is.na(observation_count)) |>
  mutate(species_observed = as.integer(species_observed))
# estimate encounter rate
pred_er <- predict(er_model, data = checklists_test, type = "response")
pred_er <- pred_er$predictions[, 2]
# convert predictions to binary (presence/absence) using the threshold
pred_binary <- as.integer(pred_er > threshold)
# calibrate
pred_calibrated <- predict(calibration_model,
                           newdata = data.frame(pred = pred_er),
                           type = "response") |>
  as.numeric()
# constrain probabilities to 0-1
pred_calibrated[pred_calibrated < 0] <- 0
pred_calibrated[pred_calibrated > 1] <- 1

# add predicted encounter rate required for count estimates
checklists_test$predicted_er <- pred_er
# estimate count
pred_count <- predict(count_model, data = checklists_test, type = "response")
pred_count <- pred_count$predictions
# relative abundance is the product of encounter rate and count
pred_abundance <- pred_calibrated * pred_count

# combine observations and estimates
obs_pred_test <- data.frame(
  id = seq_along(pred_abundance),
  # actual detection/non-detection
  obs_detected = as.integer(checklists_test$species_observed),
  obs_count = checklists_test$observation_count,
  # model estimates
  pred_binary = pred_binary,
  pred_er = pred_calibrated,
  pred_count = pred_count,
  pred_abundance = pred_abundance
)


# Encounter rate PPMs ----
# mean squared error (mse)
mse <- mean((obs_pred_test$obs_detected - obs_pred_test$pred_er)^2)

# precision-recall auc
em <- precrec::evalmod(scores = obs_pred_test$pred_binary,
                       labels = obs_pred_test$obs_detected)
pr_auc <- precrec::auc(em) |>
  filter(curvetypes == "PRC") |>
  pull(aucs)

# calculate metrics for binary prediction: sensitivity, specificity
pa_metrics <- obs_pred_test |>
  dplyr::select(id, obs_detected, pred_binary) |>
  PresenceAbsence::presence.absence.accuracy(na.rm = TRUE, st.dev = FALSE)

# combine ppms together
er_ppms[[i]] <- data.frame(
  mse = mse,
  sensitivity = pa_metrics$sensitivity,
  specificity = pa_metrics$specificity,
  pr_auc = pr_auc
)


# Count PPMs ----
# subset to only those checklists where detect occurred
detections_test <- filter(obs_pred_test, obs_detected > 0)

# count metrics, based only on checklists where detect occurred
count_spearman <- cor(detections_test$pred_count,
                      detections_test$obs_count,
                      method = "spearman")
log_count_pearson <- cor(log(detections_test$pred_count),
                         log(detections_test$obs_count),
                         method = "pearson")

# abundance metrics, based on all checklists
abundance_spearman <- cor(obs_pred_test$pred_abundance,
                          obs_pred_test$obs_count,
                          method = "spearman")
log_abundance_pearson <- cor(log(obs_pred_test$pred_abundance + 1),
                             log(obs_pred_test$obs_count + 1),
                             method = "pearson")

# combine ppms together
count_abd_ppms[[i]] <- data.frame(
  count_spearman = count_spearman,
  log_count_pearson = log_count_pearson,
  abundance_spearman = abundance_spearman,
  log_abundance_pearson = log_abundance_pearson
)

print(paste0("Iteration ", i, " of ", input$iter, " has finished."))

} # iterations





























# Calculate mean and sd across iterations for predictions ----
predictions_mean <- 
  bind_rows(predictions) %>%
  group_by(cell_id, x, y) %>%
  dplyr::summarise(in_range = max(in_range, na.rm = TRUE), 
            encounter_rate = mean(encounter_rate, na.rm = TRUE),
            count = mean(count, na.rm = TRUE),
            abundance = mean(abundance, na.rm = TRUE),
            prop_pop = mean(prop_pop, na.rm = TRUE),
            .groups = 'drop')

predictions_sd <- 
  bind_rows(predictions) %>%
  group_by(cell_id, x, y) %>%
  dplyr::summarise(in_range = max(in_range, na.rm = TRUE), 
            encounter_rate = sd(encounter_rate, na.rm = TRUE),
            count = sd(count, na.rm = TRUE),
            abundance = sd(abundance, na.rm = TRUE),
            prop_pop = sd(prop_pop, na.rm = TRUE),
            .groups = 'drop')


# rasterize
layers <- c("in_range", "encounter_rate", "count", "abundance","prop_pop")
r_pred_mean <- predictions_mean |>
  # convert to spatial features
  st_as_sf(coords = c("x", "y"), crs = crs) |>
  dplyr::select(all_of(layers)) |>
  # rasterize
  rasterize(r, field = layers)

r_pred_sd <- predictions_sd |>
  # convert to spatial features
  st_as_sf(coords = c("x", "y"), crs = crs) |>
  dplyr::select(all_of(layers)) |>
  # rasterize
  rasterize(r, field = layers)

# Mapping - thresholded maps ----
# load gis data for making maps
study_area<- read_sf(input$study_area) |>
  st_transform(crs(r_pred_mean))

# Mean predictive performance metrics ----
er_ppms_mean <- 
  bind_rows(er_ppms) %>%
  dplyr::summarise(mse = mean(mse),
            sensitivity = mean(sensitivity),
            specificity = mean(specificity),
            pr_auc = mean(pr_auc),
            .groups = 'drop')

count_abd_ppms_mean <- 
  bind_rows(count_abd_ppms) %>%
  dplyr::summarise(count_spearmen = mean(count_spearman),
            log_count_pearson = mean(log_count_pearson),
            abundance_spearman = mean(abundance_spearman),
            log_abundance_pearson = mean(log_abundance_pearson),
            .groups = 'drop')

ppms_out <- rbind(pivot_longer(er_ppms_mean, cols = c(mse, 
                                                    sensitivity, 
                                                    specificity, 
                                                    pr_auc)),
                  pivot_longer(count_abd_ppms_mean, cols = c(count_spearmen, 
                                                         log_count_pearson, 
                                                         abundance_spearman, 
                                                         log_abundance_pearson)))
colnames(ppms_out) <- c("Metric", "Value")




### Output results

################# JPEG1

MeanPercentDensity_path<- file.path(outputFolder, paste0("MeanPercentDensity", ".jpg"))
  
jpeg(filename = MeanPercentDensity_path, 
     width = 5, height = 5, units = "in", res = 300)

# map of mean proportion of population
par(mar = c(6, 0.25, 0.25, 0.25), oma = c(1,0,0,0))

# define quantile breaks, excluding zeros
brks <- ifel(r_pred_mean[["prop_pop"]] > 0, r_pred_mean[["prop_pop"]], NA) |>
  global(fun = quantile,
         probs = seq(0, 1, 0.1), na.rm = TRUE) |>
  as.numeric() |>
  unique()

# color palette
pal <- ebirdst_palettes(length(brks) - 1)
# label the bottom, middle, and top value
lbls <- round(c(min(brks)*100, median(brks)*100, max(brks)*100), 4)

# plot
par(mar = c(5, 0.25, 0.25, 0.25), oma= c(1, 0, 0, 0))

# define quantile breaks, excluding zeros
brks <- ifel(r_pred_mean[["prop_pop"]] > 0, r_pred_mean[["prop_pop"]], NA) |>
  global(fun = quantile,
         probs = seq(0, 1, 0.1), na.rm = TRUE) |>
  as.numeric() |>
  unique()

# color palette
pal <- ebirdst_palettes(length(brks) - 1)
# label the bottom, middle, and top value
lbls <- round(c(min(brks)*100, median(brks)*100, max(brks)*100), 4)

# plot
plot(r_pred_mean[["prop_pop"]],
     col = c("#e6e6e6", pal), breaks = c(0, brks),
     legend = FALSE, axes = FALSE, bty = "n", add = FALSE)
plot(study_area, border = "#000000", col = NA, lwd = 0.5, add = TRUE)

# legend
par(new = TRUE, mar = c(1, 0, 0, 0))
title <- "Mean Percent of Population"
image.plot(zlim = c(0, 1), legend.only = TRUE,
           col = pal, breaks = seq(0, 1, length.out = length(brks)),
           smallplot = c(0.5, 0.8, 0.04, 0.07),
           horizontal = TRUE,
           axis.args = list(at = c(0, 0.5, 1), labels = lbls,
                            fg = "black", col.axis = "black",
                            cex.axis = 0.75, lwd.ticks = 0.5,
                            padj = -1.5),
           legend.args = list(text = title,
                              side = 3, col = "black",
                              cex = 1, line = 0))
dev.off()


################# JPEG2
SDPercentDensity_path<- file.path(outputFolder, paste0("SDPercentDensity", ".jpg"))

# map of standard deviation of proportion of population
jpeg(filename = SDPercentDensity_path, 
     width = 5, height = 5, units = "in", res = 300)
par(mar = c(5, 0.25, 0.25, 0.25), oma= c(1, 0, 0, 0))

# define quantile breaks, excluding zeros
brks <- ifel(r_pred_sd[["prop_pop"]] > 0, r_pred_sd[["prop_pop"]], NA) |>
  global(fun = quantile,
         probs = seq(0, 1, 0.1), na.rm = TRUE) |>
  as.numeric() |>
  unique()

# color palette
pal <- ebirdst_palettes(length(brks) - 1)

# label the bottom, middle, and top value
lbls <- round(c(min(brks), median(brks), max(brks)), 4)

plot(r_pred_sd[["prop_pop"]],
     col = c("#e6e6e6", pal), breaks = c(0, brks),
     maxpixels = ncell(r_pred_sd),
     legend = FALSE, axes = FALSE, bty = "n", add = FALSE)
plot(study_area, border = "#000000", col = NA, lwd = 1, add = TRUE)

# legend
par(new = TRUE, mar = c(0, 0, 0, 0))
title <- "SD Percent of Population"
image.plot(zlim = c(0, 1), legend.only = TRUE,
           col = pal, breaks = seq(0, 1, length.out = length(brks)),
           smallplot = c(0.5, 0.8, 0.04, 0.07),
           horizontal = TRUE,
           axis.args = list(at = c(0, 0.5, 1), labels = lbls,
                            fg = "black", col.axis = "black",
                            cex.axis = 0.75, lwd.ticks = 0.5,
                            padj = -1.5),
           legend.args = list(text = title,
                              side = 3, col = "black",
                              cex = 1, line = 0))

dev.off()

#### tablas
MEAN_estimates_path<- file.path(outputFolder, paste0("MEAN_estimates", ".csv"))
write_csv(predictions_mean, MEAN_estimates_path)

SD_estimates_path<- file.path(outputFolder, paste0("SD_estimates", ".csv"))
write_csv(predictions_sd, SD_estimates_path)

ppms_predict_path<- file.path(outputFolder, paste0("ppms_predict", ".csv"))
write_csv(ppms_out, ppms_predict_path)




output<- list(MeanPercentDensity= MeanPercentDensity_path,
              SDPercentDensity= SDPercentDensity_path,
              MEAN_estimates=MEAN_estimates_path,
              SD_estimates=SD_estimates_path,
              ppms_predict=ppms_predict_path)


#### Outputing result to JSON ####
# Write the output list to the 'output.json' file in JSON format
setwd(outputFolder)
jsonlite::write_json(output, "output.json", auto_unbox = TRUE, pretty = TRUE)
