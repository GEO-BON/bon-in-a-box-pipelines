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


dfextract <- function(df, quant) {
  if(length(quant)==0) {return(colMeans(df))} else 
    return(cbind(data.frame(colMeans(df)),
                 colQuantiles(df, probs=quant)))
}




predict.bart.df <- function(object, df, quantiles = c()) {
  input.matrix <- as.matrix(df[, attr(object$fit@.xData$data@x, "term.labels")])
 
  blankout <- data.frame(matrix(ncol=(1+length(quantiles)), 
                                nrow=nrow(input.matrix)))

  whichvals <- which(complete.cases(input.matrix))
  input.matrix <- input.matrix[complete.cases(input.matrix),]
   
  pred <- dbarts:::predict.bart(object, input.matrix)
  print(1)
  pred.summary <- dfextract(pred, quant=quantiles)
  
  output <- as.matrix(pred.summary)
  blankout[whichvals,] <- output
  output <- blankout
  if (length(quantiles) > 0) {
    names(output) <- c("p", sprintf("q%i", 1:length(quantiles)))
  } else {
    names(output) <- "p"
                       
  }
  return(output)
}


variable.step <- function(x.data, y.data, ri.data=NULL, n.trees=10, iter=50, quiet=FALSE) {
  
  quietly <- function(x) {
    sink(tempfile())
    on.exit(sink())
    invisible(force(x))
  }  # THANKS HADLEY
  
  comp <- complete.cases(x.data)
  
  if(length(comp) < (nrow(x.data))) {
    message("Some rows with NA's have been automatically dropped. \n")
  }
  x.data <- x.data[comp,]
  y.data <- y.data[comp]
  
  ###############
  
  # auto-drops 
  
  quietly(model.0 <- bart.flex(x.data = x.data, y.data = y.data, 
                               ri.data = ri.data,
                               n.trees = 200))
  
  if(class(model.0)=='rbart') {
    fitobj <- model.0$fit[[1]]
  }
  if(class(model.0)=='bart') {
    fitobj <- model.0$fit
  }
  
  dropnames <- colnames(x.data)[!(colnames(x.data) %in% names(which(unlist(attr(fitobj$data@x,"drop"))==FALSE)))]
  
  if(length(dropnames) > 0) {
    message("Some of your variables have been automatically dropped by dbarts.")
    message("(This could be because they're characters, homogenous, etc.)")
    message("It is strongly recommended that you remove these from the raw data:")
    message(paste(dropnames,collapse = ' '), ' \n')
  }
  
  x.data %>% dplyr::select(-any_of(dropnames)) -> x.data  
  
  ###############
  
  nvars <- ncol(x.data)
  varnums <- c(1:nvars)
  varlist.orig <- varlist <- colnames(x.data)
  
  rmses <- data.frame(Variable.number=c(),RMSE=c())
  dropped.varlist <- c()
  
  for(var.j in c(nvars:3)) {
    
    print(noquote(paste("Number of variables included:",var.j)))
    print(noquote("Dropped:"))
    print(if(length(dropped.varlist)==0) {noquote("")} else {noquote(dropped.varlist)})
    
    rmse.list <- c()
    
    if(!quiet){pb <- txtProgressBar(min = 0, max = iter, style = 3)}
    for(index in 1:iter) {
      quietly(model.j <- bart.flex(x.data = x.data[,varnums], y.data = y.data, 
                                   ri.data = ri.data,
                                   n.trees = n.trees))
      
      quietly(vi.j <- varimp(model.j))
      if(index==1) {
        vi.j.df <- vi.j
      } else {
        vi.j.df[,index+1] <- vi.j[,2]
      }
      
      pred.p <- colMeans(pnorm(model.j$yhat.train))[y.data==1]
      pred.a <- colMeans(pnorm(model.j$yhat.train))[y.data==0]
      #e <- evaluate(p=pred.p,
      #              a=pred.a)
      #aucs <- rbind(aucs,c(var.j,e@auc)); colnames(aucs) <- c('Vars','AUC')
      
      pred.c <- c(pred.p, pred.a)
      true.c <- c(rep(1,length(pred.p)), rep(0,length(pred.a)))
      rmsej.i <- Metrics::rmse(true.c,pred.c)
      rmse.list <- c(rmse.list,rmsej.i)
      if(!quiet){setTxtProgressBar(pb, index)}
    }
    
    vi.j <- data.frame(vi.j.df[,1],
                       rowMeans(vi.j.df[,-1]))
    vi.j <- vi.j[order(vi.j[,2]),]
    
    drop.var <- vi.j[1,1]
    dropped.varlist <- c(dropped.varlist,as.character(drop.var))
    
    rmsej <- mean(rmse.list)
    
    rmses <- rbind(rmses,c(nvars-var.j,rmsej)); colnames(rmses) <- c('VarsDropped','RMSE')
    
    varnums <- varnums[!(varnums==which(varlist.orig==drop.var))]
    varlist <- varlist.orig[varnums]
    print(noquote("---------------------------------------"))
  }
  
  g1 <- ggplot2::ggplot(rmses, aes(y=RMSE, x=VarsDropped)) +
    geom_line(color="black") + geom_point(size=3) + theme_bw() +
    ylab("RMSE of model\n") + xlab("\nVariables dropped") +
    theme(axis.text = element_text(size=12),
          axis.title = element_text(size=14,face="bold")) +
    scale_x_discrete(limits=c(0:(nrow(rmses)))); print(g1)
  
  print(noquote("---------------------------------------"))
  print(noquote("Final recommended variable list"))
  varlist.final <- varlist.orig[!(varlist.orig %in% dropped.varlist[0:(which(rmses$RMSE==min(rmses$RMSE))-1)])]
  print(noquote(varlist.final))
  invisible(varlist.final)
}
