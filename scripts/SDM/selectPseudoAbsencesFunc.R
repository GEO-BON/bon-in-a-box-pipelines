
sample_background <-
  function(data,
           x,
           y,
           n,
           method = "random",
           rlayer,
           maskval = NULL,
           calibarea = NULL,
           rbias = NULL,
           sp_name = NULL) {
    . <- NULL
    if (!method[1] %in% c("random", "thickening", "biased")) {
      stop("argument 'method' was misused, available methods 'random', 'thickening'")
    }

    if (method[1] %in% c("biased") & is.null(rbias)) {
      stop("for using 'random' method a raster layer with biases data must be provided in 'rbias' argument")
    }


    # Prepare datasets
    if (class(rlayer)[1] != "SpatRaster") {
      rlayer <- terra::rast(rlayer)
    }
    if (!is.null(rbias)) {
      if(class(rbias)[1] != "SpatRaster")
        rbias <- terra::rast(rbias)
    }

    rlayer <- rlayer[[1]]
    data <- data[, c(x, y)]

    # Remove cell with presences
    rlayer[na.omit(terra::cellFromXY(rlayer, as.matrix(data)))] <- NA

    # Mask to calibration area
    if (!is.null(calibarea)) {
      rlayer <- rlayer %>% terra::crop(., calibarea) %>% terra::mask(., calibarea)
    }

    # Mask to maksvalue
    if (!is.null(maskval)) {
      if (is.factor(maskval)) {
        maskval <-
          which(levels(maskval) %in% as.character(maskval))
        rlayer <- rlayer * 1
      }
      filt <- terra::match(rlayer, maskval)
      rlayer <- terra::mask(rlayer, filt)
    }

    # Correct rbias data in case it don't match resolution or extent of rlayer
    if (method[1] %in% c("biased")) {
      if (any(!(ext(rlayer)[1:4] %in% ext(rbias)[1:4])) | all(!res(rlayer) %in% res(rbias))) {
        if(!all(res(rlayer)%in%res(rbias))){
          rbias <- terra::resample(rbias, rlayer, method="bilinear")
        }
        rbias2 <- rbias %>%
          terra::crop(., rlayer) %>%
          terra::mask(., rlayer)
        # df <- terra::as.data.frame(rlayer, xy = TRUE)
        # rbias2[] <- NA
        # rbias2[as.numeric(rownames(df))] <-
        #   terra::extract(rbias, df[c("x", "y")])[, 2]
        # rn(df)
        rbias <- rbias2
        rm(rbias2)
      }
    }

    if (method[1] %in% c("biased")) {
      rlayer <- mask(rlayer, rbias)
    }

    ncellr <- terra::global(!is.na(rlayer), sum)

    # Create density of buffers sum
    if (any(method == "thickening")) {
      data2 <- terra::vect(data, geom = c(x, y), crs = crs(rlayer))
      if (is.na(method["width"])) {
        buf_with <- mean(terra::distance(data2))
      } else {
        buf_with <- as.numeric(method["width"])
      }
      buf <- terra::buffer(data2, buf_with, quadsegs = 10)
      buf_r <- !is.na(rasterize(buf[1], rlayer))
      for (i in 2:nrow(buf)) {
        buf_r <- buf_r + !is.na(rasterize(buf[i], rlayer))
      }
      buf_r <- terra::mask(buf_r, rlayer)
    }

    if (ncellr < n) {
      message(
        "Number of background-points exceeds number of cell will be returned ",
        ncellr,
        " background-points"
      )
      cell_samp <- terra::as.data.frame(rlayer, na.rm = TRUE, cells = TRUE)[, "cell"]
      cell_samp <- terra::xyFromCell(rlayer, cell_samp) %>%
        data.frame() %>%
        dplyr::tibble()
    } else {
      cell_samp <- terra::as.data.frame(rlayer, na.rm = TRUE, cells = TRUE)[, "cell"]

      if (any(method == "random")) {
        cell_samp <-
          sample(cell_samp,
                 size = n,
                 replace = FALSE,
                 prob = NULL
          )
      } else if (any(method == "thickening")) {
        cell_samp <-
          sample(cell_samp,
                 size = n,
                 replace = FALSE,
                 prob = buf_r[cell_samp][, 1]
          )
      } else if (any(method == "biased")) {
        cell_samp <-
          sample(cell_samp,
                 size = n,
                 replace = FALSE,
                 prob = rbias[cell_samp][, 1]
          )
      }

      cell_samp <- terra::xyFromCell(rlayer, cell_samp) %>%
        data.frame() %>%
        dplyr::tibble()
    }
    colnames(cell_samp) <- c("x", "y")
    cell_samp$pr_ab <- 0
    if(!is.null(sp_name)){
      cell_samp <- tibble(sp=sp_name, cell_samp)
    }
    return(cell_samp)
  }

sample_pseudoabs <- function(data, x, y, n, method, rlayer, maskval = NULL, calibarea = NULL, sp_name = NULL) {
  . <- ID <- NULL

  if (!any(c(
    "random",
    "env_const",
    "geo_const",
    "geo_env_const",
    "geo_env_km_const"
  ) %in% method)) {
    stop(
      "argument 'method' was misused, available methods random, env_const, geo_const, geo_env_const, and geo_env_km_const"
    )
  }

    # Extract species name
    species <- unique(data$scientific_name)
  rlayer <- rlayer[[1]]
  data <- data[, c(x, y)]

  if (!is.null(calibarea)) {
    rlayer <- rlayer %>% terra::crop(., calibarea) %>% terra::mask(., calibarea)
  }

  # Random method
  if (any(method %in% "random")) {
    cell_samp <- sample_background(data = data, x = x, y = y, method = "random", n = n, rlayer = rlayer, maskval = maskval)
  }

  # env_const method
  if (any(method == "env_const")) {
    if (is.na(method["env"])) {
      stop("Provide a environmental stack/brick variables for env_const method, \ne.g. method = c('env_const', env=somevar)")
    }

    env <- method[["env"]]
    # Test extent
    if (!all(as.vector(terra::ext(env)) %in% as.vector(terra::ext(rlayer)))) {
      message("Extents do not match, raster layers used were croped to minimum extent")
      df_ext <- data.frame(as.vector(terra::ext(env)), as.vector(terra::ext(rlayer)))

      e <- terra::ext(apply(df_ext, 1, function(x) x[which.min(abs(x))]))
      env <- crop(env, e)
      rlayer <- crop(rlayer, e)
    }

    # Restriction for a given region
    envp <- inv_bio(e = env, p = data[, c(x, y)])
    envp <- terra::mask(rlayer, envp)
    cell_samp <- sample_background(data = data, x = x, y = y, method = "random", n = n, rlayer = envp, maskval = maskval)
  }

  # geo_const method
  if (any(method == "geo_const")) {
    if (!"width" %in% names(method)) {
      stop("Provide a width value for 'geo_const' method, \ne.g. method=c('geo_const', width='50000')")
    }

    # Restriction for a given region
    envp <- inv_geo(e = rlayer, p = data[, c(x, y)], d = as.numeric(method["width"]))
     cell_samp <- sample_background(data = data, x = x, y = y, method = "random", n = n, rlayer = envp, maskval = maskval)
  }

  # geo_env_const method
  if (any(method == "geo_env_const")) {
    if (!all(c("env", "width") %in% names(method))) {
      stop("Provide a width value and environmental stack/brick variables for 'geo_env_const' method, \ne.g. method=c('geo_env_const', width='50000', env=somevar)")
    }

    env <- method[["env"]]

    # Test extent
    if (!all(as.vector(terra::ext(env)) %in% as.vector(terra::ext(rlayer)))) {
      message("Extents do not match, raster layers used were croped to minimum extent")
      df_ext <- data.frame(as.vector(terra::ext(env)), as.vector(terra::ext(rlayer)))

      e <- terra::ext(apply(df_ext, 1, function(x) x[which.min(abs(x))]))
      env <- crop(env, e)
      rlayer <- crop(rlayer, e)
    }

    # Restriction for a given region
    envp <- inv_geo(e = rlayer, p = data[, c(x, y)], d = as.numeric(method["width"]))
    envp2 <- inv_bio(e = env, p = data[, c(x, y)])

    envp <- (envp2 + envp)
    rm(envp2)
    envp <- terra::mask(rlayer, envp)
    cell_samp <- sample_background(data = data, x = x, y = y, method = "random", n = n, rlayer = envp, maskval = maskval)
  }

  # geo_env_km_const
  if (any(method == "geo_env_km_const")) {
    if (!all(c("env", "width") %in% names(method))) {
      stop("Provide a width value and environmental stack/brick variables for 'geo_env_km_const' method, \ne.g. method=c('geo_env_const', width='50000', env=somevar)")
    }

    env <- method[["env"]]

    # Test extent
    if (!all(as.vector(terra::ext(env)) %in% as.vector(terra::ext(rlayer)))) {
      message("Extents do not match, raster layers used were croped to minimum extent")
      df_ext <- data.frame(as.vector(terra::ext(env)), as.vector(terra::ext(rlayer)))

      e <- terra::ext(apply(df_ext, 1, function(x) x[which.min(abs(x))]))
      env <- crop(env, e)
      rlayer <- crop(rlayer, e)
    }

    # Restriction for a given region
    envp <- inv_geo(e = rlayer, p = data[, c(x, y)], d = as.numeric(method["width"]))
    envp2 <- inv_bio(e = env, p = data[, c(x, y)])
    envp <- (envp2 + envp)
    envp <- terra::mask(rlayer, envp)
    rm(envp2)

    if (!is.null(maskval)) {
      if (is.factor(maskval)) {
        maskval <-
          which(levels(maskval) %in% as.character(maskval))
        rlayer <- rlayer * 1
      }
      filt <- terra::match(rlayer, maskval)
      rlayer <- terra::mask(rlayer, filt)
      rm(filt)
    }

    envp <- terra::mask(rlayer, envp)

    # K-mean procedure
    env_changed <- terra::mask(env, envp)
    env_changed <- terra::as.data.frame(env_changed, xy = TRUE)
    env_changed <- stats::na.exclude(env_changed)

    suppressWarnings(km <- stats::kmeans(env_changed, centers = n))
    cell_samp <- km$centers[, 1:2] %>% data.frame()
    val <- terra::extract(envp, cell_samp, method = "simple", xy = TRUE) %>%
      dplyr::select(-c(ID, x, y))
    cell_samp <-
      cell_samp %>% dplyr::mutate(val = val[, 1])
    cell_samp <- cell_samp[!is.na(cell_samp$val), -3]
    cell_samp <- dplyr::tibble(cell_samp)
    cell_samp$pr_ab <- 0
  }

   
  cell_samp <- dplyr::bind_cols(id = 1:nrow(cell_samp),
                      scientific_name = species,
                      cell_samp |> data.frame()) |>
    setNames(c("id", "scientific_name", "lon", "lat"))

  return(cell_samp)

}

bio <- function(data, env_layer) {
  . <- NULL
  if (class(data)[1] != "data.frame") {
    data <- data.frame(data)
  }
  if (!methods::is(env_layer, "SpatRaster")) {
    env_layer <- terra::rast(env_layer)
  }

  data <- na.omit(data)

  result <- env_layer[[1]]
  result[] <- NA

  minv <- apply(data, 2, min)
  maxv <- apply(data, 2, max)
  vnames <- names(data)

  data_2 <- data %>%
    na.omit() %>%
    apply(., 2, sort) %>%
    data.frame()

  rnk <- function(x, y) {
    b <- apply(y, 1, FUN = function(z) sum(x < z))
    t <- apply(y, 1, FUN = function(z) sum(x == z))
    r <- (b + 0.5 * t) / length(x)
    i <- which(r > 0.5)
    r[i] <- 1 - r[i]
    r * 2
  }

  var_df <- terra::as.data.frame(env_layer)
  var_df <- na.omit(var_df)

  k <- (apply(t(var_df) >= minv, 2, all) &
    apply(t(var_df) <= maxv, 2, all))

  for (j in vnames) {
    var_df[k, j] <- rnk(
      data_2[, j],
      var_df[k, j, drop = FALSE]
    )
  }
  var_df[!k, ] <- 0
  res <- apply(var_df, 1, min)
  result[as.numeric(names(res))] <- res
  return(result)
}

inv_bio <- function(e, p) {
  if (!methods::is(e, "SpatRaster")) {
    e <- terra::rast(e)
  }
  r <- bio(data = terra::extract(e, p)[-1], env_layer = e)
  r <- (r - terra::minmax(r)[1]) /
    (terra::minmax(r)[2] - terra::minmax(r)[1])
  r <- (1 - r) >= 0.99 # environmental constrain
  r[which(r[, ] == FALSE)] <- NA
  return(r)
}


#' Inverse geo
#'
#' @noRd
#'
inv_geo <- function(e, p, d) {
  colnames(p) <- c("x", "y")
  p <- terra::vect(p, geom = c("x", "y"), crs = terra::crs(e))
  b <- terra::buffer(p, width = d)
  b <- terra::rasterize(b, e, background = 0)
  e <- terra::mask(e, b, maskvalues = 1)
  return(e)
}

#' Boyce
#'
#' @description This function calculate Boyce index performance metric. Codes were adapted from
#' enmSdm package.
#'
#' @noRd
boyce <- function(pres,
                  contrast,
                  n_bins = 101,
                  n_width = 0.1) {
  lowest <- min(c(pres, contrast), na.rm = TRUE)
  highest <- max(c(pres, contrast), na.rm = TRUE) + .Machine$double.eps
  window_width <- n_width * (highest - lowest)

  lows <- seq(lowest, highest - window_width, length.out = n_bins)
  highs <- seq(lowest + window_width + .Machine$double.eps, highest, length.out = n_bins)

  ## initiate variables to store predicted/expected (P/E) values
  freq_pres <- NA
  freq_contrast <- NA

  # tally proportion of test presences/background in each class
  for (i in 1:n_bins) {
    # number of presence predictions in a class
    freq_pres[i] <-
      sum(pres >= lows[i] & pres < highs[i], na.rm = TRUE)

    # number of background predictions in this class
    freq_contrast[i] <-
      sum(contrast >= lows[i] & contrast < highs[i], na.rm = TRUE)
  }

  # mean bin prediction
  mean_pred <- rowMeans(cbind(lows, highs))

  # add small number to each bin that has 0 background frequency but does have a presence frequency > 0
  if (any(freq_pres > 0 & freq_contrast == 0)) {
    small_value <- 0.5
    freq_contrast[freq_pres > 0 & freq_contrast == 0] <- small_value
  }

  # remove classes with 0 presence frequency
  if (any(freq_pres == 0)) {
    zeros <- which(freq_pres == 0)
    mean_pred[zeros] <- NA
    freq_pres[zeros] <- NA
    freq_contrast[zeros] <- NA
  }

  # remove classes with 0 background frequency
  if (any(0 %in% freq_contrast)) {
    zeros <- which(freq_pres == 0)
    mean_pred[zeros] <- NA
    freq_pres[zeros] <- NA
    freq_contrast[zeros] <- NA
  }

  P <- freq_pres / length(pres)
  E <- freq_contrast / length(contrast)
  PE <- P / E

  # remove NAs
  rm_nas <- stats::complete.cases(data.frame(mean_pred, PE))
  # mean_pred <- mean_pred[rm_nas]
  # PE <- PE[rm_nas]

  # calculate Boyce index
  result <- stats::cor(
    x = ifelse(is.na(mean_pred), 0, mean_pred),
    y = ifelse(is.na(PE), 0, PE), method = "spearman"
  )
  return(result)
}
