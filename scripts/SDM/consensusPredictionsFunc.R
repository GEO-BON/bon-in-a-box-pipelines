extract_auc <- function(pa, id_p, id_a) {
  
  return(dismo::evaluate(p = pa[id_p], a = pa[id_a])@auc)
  
  }
  
model_consensus <- function(models, presence_background, method = "median", min_auc = 0.5, top_k_auc = NULL) {
 
  pa_vals <- terra::extract(models, dplyr::select(presence_background, lon, lat)) |> dplyr::select(-ID)
  p_ind <- which(presence_background$pa == 1)
  a_ind <- which(presence_background$pa == 0)
  
  mod_auc <- pa_vals |> dplyr::mutate_all(extract_auc, p_ind, a_ind) |> slice_head() |>
    tidyr::pivot_longer(cols = starts_with("sdm"), names_to = "model", values_to = "auc")
  
  mod_auc <- dplyr::filter(mod_auc, auc > min_auc)

   if (!is.null(top_k_auc)) {
     
     top_k_auc <- min(top_k_auc, nrow(mod_auc)) #ensure we do not select more than the number of models
     mod_auc <- arrange(mod_auc, desc(auc))
     mod_auc <- mod_auc[1:top_k_auc, ] #selecting top k models
   }

  mod_selected <- dplyr::pull(mod_auc, model)
  
  models <- models |> terra::subset(mod_selected)
  if (method == "median") {
      consensus <- terra::app(models, median)
    } else if (method == "mean") {
      consensus <- terra::app(models, mean)
    } else if (method == "WA") {
      consensus <- terra::weighted.mean(models, dplyr::pull(mod_auc, auc))
    }
  return(consensus)
}
