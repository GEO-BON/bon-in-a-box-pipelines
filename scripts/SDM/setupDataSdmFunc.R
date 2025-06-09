setup_sdm_data<- function(
    presence,
    absence,
    predictors,
    partition_type = c("bootstrap"),
    orientation = "lat_lon",
    runs_n = 2,
    boot_proportion = 0.7,
    cv_partitions = NULL,
    seed=NULL) {
  
  
  #creates metadata for this run
  presence <- presence |> dplyr::mutate(pa = 1)
  absence <- absence |> dplyr::mutate(pa = 0)
  
  # Data partition-----
  message("performing data partition")
  #Crossvalidation, repetated crossvalidation and jacknife
  if (partition_type == "spatial_block") {
    blocks <- ENMeval::get.block(presence[,c("lon", "lat")], absence[,c("lon", "lat")], orientation = orientation)
    
  }
  if (partition_type == "crossvalidation") {
    if (nrow(presence) < 11) {
      message("data set has 10 presence or less, forcing jacknife")
      #forces jacknife
      cv_partitions <- nrow(presence)
      runs_n <- 1
    }
    if (is.null(runs_n)) stop("runs_n must be specified in crossvalidation")
    if (is.null(cv_partitions)) stop("cv_partitions must be specified in crossvalidation")
    if (runs_n == 1) {
      #Crossvalidation
      if (!missing(seed)) set.seed(seed) #reproducibility
      group <- dismo::kfold(presence, cv_partitions)
      if (!missing(seed)) set.seed(seed)
      bg.grp <- dismo::kfold(absence, cv_partitions)
      cv_0 <- c(group, bg.grp)
    }
    if (runs_n > 1) {
      # Repeated CV
      cv.pres <- replicate(n = runs_n,
                           dismo::kfold(presence, cv_partitions))
      dimnames(cv.pres) <- list(NULL, paste0("run", 1:runs_n))
      cv.back <- replicate(n = runs_n,
                           dismo::kfold(absence, cv_partitions))
      dimnames(cv.back) <- list(NULL, paste0("run", 1:runs_n))
      cv.matrix <- rbind(cv.pres, cv.back)
    }
  }
  # Bootstrap
  if (partition_type == "bootstrap") {
    
    if (boot_proportion > 1 | boot_proportion <= 0)
      stop("bootstrap training set proportion must be between 0 and 1")
    if (is.null(runs_n))
      stop("runs_n must be specified")
    if (!missing(seed)) set.seed(seed)
    boot.pres <- replicate(n = runs_n,
                           sample(
                             x = seq_along(1:nrow(presence)),
                             size = nrow(presence) * boot_proportion,
                             replace = FALSE
                           ))
    if (!missing(seed)) set.seed(seed)
    boot.back <- replicate(n = runs_n,
                           sample(
                             x = seq_along(1:nrow(absence)),
                             size = nrow(absence) * boot_proportion,
                             replace = FALSE
                           ))
    boot_p <- matrix(data = 1,
                     nrow = nrow(presence),
                     ncol = runs_n,
                     dimnames = list(NULL, paste0("run", 1:runs_n)))
    boot_a <- matrix(data = 1,
                     nrow = nrow(absence),
                     ncol = runs_n,
                     dimnames = list(NULL, paste0("run", 1:runs_n)))
    for (i in seq_along(1:runs_n)) {
      boot_p[, i][boot.pres[, i]] <- 0
    }
    for (i in seq_along(1:runs_n)) {
      boot_a[, i][boot.back[, i]] <- 0
    }
    boot.matrix <- rbind(boot_p, boot_a)
    
  }
  
    presence <-
  dplyr::mutate(presence, id = as.double(id))
  absence <-
  dplyr::mutate(absence, id = as.double(id))
  presence_absence <- dplyr::bind_rows(presence, absence)
  
  if (partition_type == "none" | runs_n == 1) presence_absence <- bind_cols("run1" = 1, presence_absence)
  if (partition_type == "spatial_block") presence_absence <- bind_cols("run1" = c(blocks$occs.grp, blocks$bg.grp), presence_absence)
  if (partition_type == "crossvalidation") presence_absence <- data.frame(cv.matrix, presence_absence)
  if (partition_type == "bootstrap") presence_absence <- data.frame(boot.matrix, presence_absence)
  
  env_vals <- terra::extract(predictors, dplyr::select(presence_absence, lon, lat))
  presence_absence <- dplyr::bind_cols(presence_absence,
                                          env_vals) |> dplyr::select(-ID)
  
  return(presence_absence)
}
