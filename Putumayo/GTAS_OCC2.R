#### Una temporada con covariables de sitio ########################################################################################### 

dir_work<- this.path::this.path() %>% dirname()

setwd(dir_work)

library("unmarked")
data<-read.table("Venado_S3_covariables_sitio_10D.txt",header=TRUE)

B.mean <- mean(data$B)
B.sd <- sd(data$B)
B.z <- (data$B - B.mean)/B.sd
H.mean <- mean(data$H)
H.sd <- sd(data$H)
H.z <- (data$H - H.mean)/H.sd
E.mean <- mean(data$E)
E.sd <- sd(data$E)
E.z <- (data$E - E.mean)/E.sd
cor(B.z,H.z)
cor(B.z,E.z)
cor(H.z,E.z)

data.umf <- unmarkedFrameOccu(y=cbind(data$O1,data$O2,data$O3,data$O4,data$O5,data$O6,data$O7,data$O8,data$O9,data$O10,data$O11),
                              siteCovs=data.frame(BOSQUE=B.z,HUELLA=H.z,ELEVAC=E.z),
                              obsCovs=NULL)
summary(data.umf)
plot(data.umf)

model<-occu(~1 ~ 1,data.umf)
model
summary(model)
coef(model) 						
resultados<-plogis(coef(model))	
(psiSE<-backTransform(model,type="state")) 
(pSE<-backTransform(model,type="det"))
(ciPsi<-confint(psiSE))
(ciP<-confint(pSE))
Tabla_res<-rbind(psi=c(resultados[1],ciPsi),p=c(resultados[2],ciP))
colnames(Tabla_res)<-c("Resultado","ICbajo","ICalto")
Tabla_res
plot(1:2,Tabla_res[,"Resultado"],xlim=c(0.5,2.5),ylim=0:1,col=c("blue","darkgreen"),pch=16,cex=2,cex.lab=1.5,xaxt="n",ann=F)
axis(1, 1:2, labels=c(expression(psi),expression(italic(p))),cex.axis=1.5)
arrows(1:2,Tabla_res[,"ICbajo"],1:2,Tabla_res[,"ICalto"],angle=90,length=0.1,code=3,col=c("blue","darkgreen"),lwd=2)

(m0<-occu(~1 ~1,data.umf))
backTransform(m0,type="state")
backTransform(m0,type="det")

(m1<-occu(~1 ~BOSQUE,data.umf))
(m2<-occu(~1 ~HUELLA,data.umf))
(m3<-occu(~1 ~ELEVAC,data.umf))
(m4<-occu(~1 ~BOSQUE+ELEVAC,data.umf))
(m5<-occu(~1 ~HUELLA+ELEVAC,data.umf))



# Put the fitted models in a "fitList"
fms <- fitList("psi(.)p(.)"         = m0,
               "psi(B)p(.)"         = m1,
               "psi(H)p(.)"         = m2,
               "psi(E)p(.)"         = m3,
               "psi(B+E)p(.)"       = m4,
               "psi(H+E)p(.)"       = m5)

# Rank them by AIC
(ms <- modSel(fms))

#Get results
coef(ms)

# Expected occupancy over range of BOSQUE
newData2 <- data.frame(BOSQUE=seq(-1.6, 1.7, by=0.1))
E.psi <- predict(m1, type="state", newdata=newData2, appendData=TRUE)
head(E.psi)

# Plot it again, but this time convert the x-axis back to original scale
plot(Predicted ~ BOSQUE, E.psi, type="l", ylim=c(0,1), col="blue",
     xlab="Porcentaje de Bosque",
     ylab="Probabilidad de ocupacion esperada",
     xaxt="n")
xticks <- -2:2
xlabs <- xticks*B.sd + B.mean
axis(1, at=xticks, labels=round(xlabs))
lines(lower ~ BOSQUE, E.psi, type="l", col=gray(0.5))
lines(upper ~ BOSQUE, E.psi, type="l", col=gray(0.5))

# Expected occupancy over range of ELEVACION
newData1 <- data.frame(ELEVAC=seq(-1.1, 2.5, by=0.1))
E.psi <- predict(m3, type="state", newdata=newData1, appendData=TRUE)
head(E.psi)

# Plot it again, but this time convert the x-axis back to original scale
plot(Predicted ~ ELEVAC, E.psi, type="l", ylim=c(0,1), col="red",
     xlab="Elevacion (msnm)",
     ylab="Probabilidad de ocupacion esperada",
     xaxt="n")
xticks <- -2:2
xlabs <- xticks*E.sd + E.mean
axis(1, at=xticks, labels=round(xlabs))
lines(lower ~ ELEVAC, E.psi, type="l", col=gray(0.5))
lines(upper ~ ELEVAC, E.psi, type="l", col=gray(0.5))

# Expected occupancy over range of HUELLA
newData3 <- data.frame(HUELLA=seq(-1.5, 1.8, by=0.1))
E.psi <- predict(m2, type="state", newdata=newData3, appendData=TRUE)
head(E.psi)

# Plot it again, but this time convert the x-axis back to original scale
plot(Predicted ~ HUELLA, E.psi, type="l", ylim=c(0,1), col="green",
     xlab="Indice de Huella Humana",
     ylab="Probabilidad de ocupacion esperada",
     xaxt="n")
xticks <- -2:2
xlabs <- xticks*H.sd + H.mean
axis(1, at=xticks, labels=round(xlabs))
lines(lower ~ HUELLA, E.psi, type="l", col=gray(0.5))
lines(upper ~ HUELLA, E.psi, type="l", col=gray(0.5))