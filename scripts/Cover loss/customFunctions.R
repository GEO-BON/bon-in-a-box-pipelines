Scalebar = function(bar.text='500 km', xpos=0.5, ypos=0.2, lbar=500, cex=1, offset=0.5) { # text legend, xpos: position on x axis (in % of x axis), ypos: same for y axis, lbar = length of scale in km
  
  library(raster)
  # Get plot coordinates
  pc = par("usr") 
  
  # get mean latitude of current map
  mLAT = mean(pc[3:4])
  
  # create fake points at mean latitute, 1° of distance on longitudinal axi
  P1=c(0,mLAT);P2=c(1,mLAT)
  
  # compute distance in meters and degrees, between two points at mean latitude, and at 1° of distance along longitudinal axis
  distDEG = 1 # distance between points in °
  distMET = pointDistance(cbind(c(0,1), c(mLAT,mLAT)), lonlat=TRUE)[2,1] # distance in meters
  
  # find conversion factors degrees to meters
  CF = distDEG/distMET
  
  # compute lbar in °
  lbarD = CF*(lbar*1000)
  
  y.bar = rep(pc[3]+((pc[4]-pc[3])*ypos),2)
  x.c = pc[1]+((pc[2]-pc[1])*xpos)
  x.bar = c(x.c-lbarD/2 , x.c+lbarD/2  )
  
  lines(x.bar, y.bar)
  text(mean(x.bar), mean(y.bar), labels=bar.text, pos=1, cex=cex, offset=offset)
  
}
