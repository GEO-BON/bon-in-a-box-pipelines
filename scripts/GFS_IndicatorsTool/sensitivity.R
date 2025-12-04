

library(dplyr)
library(glmmTMB)
library(tidyverse)
library(ggeffects)
library(patchwork)

input <- fromJSON(file=file.path(outputFolder, "input.json"))


#load data



# #get the uncertainty in the indicator and mean expected change if uncertainty added/subtracted, given a certain parameter
# get_change_uncertainty <- function(effect_df, param, uncertainty) {
#   
#   #define the expeted indicator , given the parameter
#   mean_ind <- effect_df$predicted[effect_df$predictor == param]
#   mean_lwst_ind <- effect_df$predicted[effect_df$predictor == param - uncertainty]
#   mean_highst_ind <- effect_df$predicted[effect_df$predictor == param + uncertainty]
#   
#   #mean change in indicator
#   change_lwr <- diff(c(mean_ind, mean_lwst_ind))
#   change_upr <- diff(c(mean_ind, mean_highst_ind))
#   
#   #get uncertainty of given parameter size
#   st_error <- effect_df$std.error[effect_df$predictor == param]
#   
#   
#   df <- data.frame(st_error = st_error,  indicator_lowest_expected = change_lwr, indicator_highest_expected = change_upr)
#   return(df)
# }
# 




get_all_uncertainties <- function(buffer_user, buffer_uncertainty, distance_user, distance_uncertainty, density_user,
                              density_uncertainty, NeNc_ratio_user, NeNc_ratio_uncertainty) {
  
  #load data
  data <- readRDS("/scripts/GFS_IndicatorsTool/complete_output_unnested_without_CORINE.rds")
  #load full models used in Analysis/01a_modelling_Ne500.R or Analysis/01b_modelling_PM.R
  mod_Ne500 <- readRDS("/scripts/GFS_IndicatorsTool/model_Ne500.rds")
  mod_PM <- readRDS("/scripts/GFS_IndicatorsTool/model_PM.rds")
  
  #set limits of uncertainty (we should not predict values outside the range used in the model)
  limits_buffer <- c(min(data$buffer_size), max(data$buffer_size))
  limits_distance <- c(min(data$dist_pop), max(data$dist_pop))
  limits_density <- c(min(data$pop_dens), max(data$pop_dens))
  limits_NeNc_ratio <- c(min(data$NeNc_ratio), max(data$NeNc_ratio)) 
  print(buffer_user)

  #check if any variable range is out of range of model
  if (buffer_user + buffer_uncertainty > max(data$buffer_size) | buffer_user - buffer_uncertainty < min(data$buffer_size)) {
    print("Buffer or buffer uncertainty out of range")
    return()
  }
  if (distance_user + distance_uncertainty > max(data$dist_pop) | distance_user - distance_uncertainty < min(data$dist_pop)) {
    print("Distance or distance uncertainty out of range")
    return()
  }
  if (density_user + density_uncertainty > max(data$pop_dens) | density_user - density_uncertainty < min(data$pop_dens)) {
    print("Density or denstity uncertainty out of range")
    return()
  }
  if (NeNc_ratio_user + NeNc_ratio_uncertainty > max(data$NeNc_ratio) | NeNc_ratio_user - NeNc_ratio_uncertainty < min(data$NeNc_ratio)) {
    print("Ne:Nc ratio or Ne:Nc ratio uncertainty out of range")
    return()
  }
  
  #log-transform and scale all input parameters, if necessary
  ##buffer
  scale_buffer <- attr(data$buffer_log_sc  , "scaled:scale")
  center_buffer <- attr(data$buffer_log_sc, "scaled:center")
  needed_buffers_tr <- (log(c(buffer_user - buffer_uncertainty, buffer_user, buffer_user + buffer_uncertainty)) - center_buffer) / scale_buffer
  needed_buffers_tr <- paste(needed_buffers_tr, collapse = ",")
  ##distance
  scale_distance <- attr(data$distance_log_sc  , "scaled:scale")
  center_distance <- attr(data$distance_log_sc, "scaled:center")
  needed_distances_tr <- (log(c(distance_user - distance_uncertainty, distance_user, distance_user + distance_uncertainty)) - center_distance) / scale_distance
  needed_distances_tr <- paste(needed_distances_tr, collapse = ",")
  ##density
  scale_density <- attr(data$density_log_sc  , "scaled:scale")
  center_density <- attr(data$density_log_sc, "scaled:center")
  needed_densities_tr <- (log(c(density_user - density_uncertainty, density_user, density_user + density_uncertainty)) - center_density) / scale_density
  needed_densities_tr <- paste(needed_densities_tr, collapse = ",")
  ##NeNc ratio (no need for transformation)
  needed_NeNc_ratios <- c(NeNc_ratio_user - NeNc_ratio_uncertainty, NeNc_ratio_user, NeNc_ratio_user + NeNc_ratio_uncertainty)
  needed_NeNc_ratios <- paste(needed_NeNc_ratios, collapse = ",")
  
  #get predictions and backtransform & round the predictors, if needed
  ##buffer
  effects_Ne500_buffer <- ggpredict(mod_Ne500, terms = paste("buffer_log_sc [", needed_buffers_tr, "]"), interval = "confidence")
  effects_Ne500_buffer$predictor <- round(exp(effects_Ne500_buffer$x * scale_buffer + center_buffer),2)
  effects_PM_buffer <- ggpredict(mod_PM, terms = paste("buffer_log_sc [", needed_buffers_tr, "]"), interval = "confidence")
  effects_PM_buffer$predictor <- round(exp(effects_PM_buffer$x * scale_buffer + center_buffer), 2)
  ##distance
  effects_Ne500_distance <- ggpredict(mod_Ne500, terms = paste("distance_log_sc [", needed_distances_tr, "]"), interval = "confidence")
  effects_Ne500_distance$predictor <- round(exp(effects_Ne500_distance$x * scale_distance + center_distance),2)
  effects_PM_distance <- ggpredict(mod_PM, terms = paste("distance_log_sc [", needed_distances_tr, "]"), interval = "confidence")
  effects_PM_distance$predictor <- round(exp(effects_PM_distance$x * scale_distance + center_distance), 2)
  ##density
  effects_Ne500_density <- ggpredict(mod_Ne500, terms = paste("density_log_sc [", needed_densities_tr, "]"), interval = "confidence")
  effects_Ne500_density$predictor <- round(exp(effects_Ne500_density$x * scale_density + center_density),2)
  effects_PM_density <- ggpredict(mod_PM, terms = paste("density_log_sc [", needed_densities_tr, "]"), interval = "confidence")
  effects_PM_density$predictor <- round(exp(effects_PM_density$x * scale_density + center_density), 2)
  ##NeNc ratio
  effects_Ne500_NeNc_ratio <- ggpredict(mod_Ne500, terms = paste("NeNc_ratio [", needed_NeNc_ratios, "]"), interval = "confidence")
  effects_Ne500_NeNc_ratio$predictor <- effects_Ne500_NeNc_ratio$x
  effects_PM_NeNc_ratio <- ggpredict(mod_PM, terms = paste("NeNc_ratio [", needed_NeNc_ratios, "]"), interval = "confidence")
  effects_PM_NeNc_ratio$predictor <- effects_PM_NeNc_ratio$x
  
  
  #start dataframe for output
  output_df <- data.frame()

  #make output dataframes
  buffer_output <- data.frame(variable_OI = "buffer", 
                              std_error_Ne500 = effects_Ne500_buffer$std.error[effects_Ne500_buffer$predictor == buffer_user], 
                              Ne500_lwr = min(effects_Ne500_buffer$predicted),
                              Ne500_upr = max(effects_Ne500_buffer$predicted), 
                              Ne500_stability = max(effects_Ne500_buffer$predicted) - min(effects_Ne500_buffer$predicted), 
                              std_error_PM = effects_PM_buffer$std.error[effects_PM_buffer$predictor == buffer_user],
                              PM_lwr = min(effects_PM_buffer$predicted),
                              PM_upr = max(effects_PM_buffer$predicted),
                              PM_stability = max(effects_PM_buffer$predicted) - min(effects_PM_buffer$predicted)  )
  output_df <- rbind(output_df, buffer_output)
  
  distance_output <- data.frame(variable_OI = "distance", 
                              std_error_Ne500 = effects_Ne500_distance$std.error[effects_Ne500_distance$predictor == distance_user], 
                              Ne500_lwr = min(effects_Ne500_distance$predicted),
                              Ne500_upr = max(effects_Ne500_distance$predicted), 
                              Ne500_stability = max(effects_Ne500_distance$predicted) - min(effects_Ne500_distance$predicted), 
                              std_error_PM = effects_PM_distance$std.error[effects_PM_distance$predictor == distance_user],
                              PM_lwr = min(effects_PM_distance$predicted),
                              PM_upr = max(effects_PM_distance$predicted),
                              PM_stability = max(effects_PM_distance$predicted) - min(effects_PM_distance$predicted)    )
  output_df <- rbind(output_df, distance_output)
  
  density_output <- data.frame(variable_OI = "density", 
                              std_error_Ne500 = effects_Ne500_density$std.error[effects_Ne500_density$predictor == density_user], 
                              Ne500_lwr = min(effects_Ne500_density$predicted),
                              Ne500_upr = max(effects_Ne500_density$predicted), 
                              Ne500_stability = max(effects_Ne500_density$predicted) - min(effects_Ne500_density$predicted), 
                              std_error_PM = effects_PM_density$std.error[effects_PM_density$predictor == density_user],
                              PM_lwr = min(effects_PM_density$predicted),
                              PM_upr = max(effects_PM_density$predicted),
                              PM_stability = max(effects_PM_density$predicted) - min(effects_PM_density$predicted)    )
  output_df <- rbind(output_df, density_output)
  
  NeNc_ratio_output <- data.frame(variable_OI = "NeNc_ratio", 
                              std_error_Ne500 = effects_Ne500_NeNc_ratio$std.error[effects_Ne500_NeNc_ratio$predictor == NeNc_ratio_user], 
                              Ne500_lwr = min(effects_Ne500_NeNc_ratio$predicted),
                              Ne500_upr = max(effects_Ne500_NeNc_ratio$predicted), 
                              Ne500_stability = max(effects_Ne500_NeNc_ratio$predicted) - min(effects_Ne500_NeNc_ratio$predicted),
                              std_error_PM = effects_PM_NeNc_ratio$std.error[effects_PM_NeNc_ratio$predictor == NeNc_ratio_user],
                              PM_lwr = min(effects_PM_NeNc_ratio$predicted),
                              PM_upr = max(effects_PM_NeNc_ratio$predicted),
                              PM_stability = max(effects_PM_NeNc_ratio$predicted) - min(effects_PM_NeNc_ratio$predicted)    )
  output_df <- rbind(output_df, NeNc_ratio_output)
  
  
  
  
  
  return(output_df)
}

table <- get_all_uncertainties(buffer_user =  input$buffer_user, buffer_uncertainty = input$buffer_uncertainty, 
                               distance_user =input$distance_user, distance_uncertainty = input$distance_uncertainty, 
                               density_user = input$density_user, density_uncertainty = input$density_uncertainty, 
                               NeNc_ratio_user = input$NeNc_ratio_user, NeNc_ratio_uncertainty = input$NeNc_ratio_uncertainty)

print(table)
## Write output
path <- file.path(outputFolder, "sensitivity_table.tsv")

write.table(table, path,
            append = F, row.names = F, col.names = T, sep = "\t", quote=F)

output <- list("table" = path)
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))
