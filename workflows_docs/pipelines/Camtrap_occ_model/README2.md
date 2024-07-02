---
title: "Add horizontal scrol"
author: "KTy"
date: "9/21/2018"
output: 
  #md_document:
  github_document:
    md_extension: +gfm_auto_identifiers
    preserve_yaml: true
    toc: true
    toc_depth: 6
---

Add horizontal scrol
================
KTy
9/21/2018

- [R Markdown](#r-markdown)
  - [Want to add horizontal scroll bar around a
    plot](#want-to-add-horizontal-scroll-bar-around-a-plot)

## R Markdown

### Want to add horizontal scroll bar around a plot

``` r
set.seed(2300)
xdf1 <- data.frame(  var1 = rnorm(  10000 , mean = 5000 , sd = 10) , str1 = rep("a0",10000)  )

for ( x in 10:50 ){
  n <- sample(x = c(10,0.1) , size = 1)
  xdf2 <- data.frame( var1 = rnorm(  x*n*1000 , mean = 5000+(x/2) , sd = 10) , str1 = rep(paste0("a",x),x*n*1000))
  xdf1 <- rbind(xdf1,xdf2)
  }

plot1 <- ggplot(  data = xdf1  , aes( x = str1 , y = var1  ))  + 
  geom_violin(fill='grey90', scale = 'count', colour = 'grey70') + 
   geom_boxplot( width = 0.2 ,  alpha = 0.1 , colour = 'grey30')+
  theme_bw()+
  theme(axis.text.x =  element_text(angle = 45, hjust = 1 ,vjust = 1))
```

<style>
  .superbigimage{
      overflow-x:scroll;
      white-space: nowrap;
  }
&#10;  .superbigimage img{
     max-width: none;
  }
&#10;
</style>
This produces the plot with a special css class

<div class="superbigimage">

![](README2_files/figure-gfm/plot_it%20-1.png)<!-- -->

</div>
