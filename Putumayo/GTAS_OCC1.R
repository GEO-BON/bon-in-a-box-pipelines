#### Una temporada sin covariables ########################################################################################### 

library(unmarked)
data<-read.table("Borugo_S1_sin_covariables_5D.txt",header=TRUE)
str(data)
data1<-unmarkedFrameOccu(y=data,siteCovs=NULL,obsCovs=NULL)
data1
summary(data1)  
plot(data1)
model<-occu(~1 ~ 1,data1)
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

##############################################################################################################################