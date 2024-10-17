Species distributions are an important EBV in the ‘species populations’ class. Knowing where species are is essential for understanding biodiversity patterns and informing conservation efforts. However, less than 10% of the world is well sampled, and even the longest running and well-sampled biodiversity observation networks have substantial data gaps. Information on species occurrences is often sparse and heavily spatially and taxonomically biased, necessitating the need for species distribution models (SDMs) to fill these data gaps and provide a better, less biased idea of where species are. SDM outputs be used as key base layers for a wide variety of purposes including: creating maps for sampling prioritization, quantifying the impact of environmental stressors on species, mapping habitat suitability for at-risk species, mapping biodiversity hotspots across the landscape, identifying the locations of conservation priorities and protected area expansion, identifying sampling gaps and the needed locations of future sampling, and calculating a range of biodiversity indicators including the Species Habitat Index (SHI), the Species Protection Index (SPI)

### **MaxEnt**

**Methods:**

SDMs predict where species are likely to occur based on a suite of environmental variables that are associated with known occurrences (Peterson, 2001; Elith and Leathwick, 2009). The MaxEnt pipeline pulls occurrences of the species of interest from GBIF and environmental raster layers from the GEO BON STAC catalog. Then, the pipeline cleans the GBIF data by only including one occurrence per pixel and  removes collinearity between the environmental layers. Third, the pipeline creates a set of pseudo-absences (background points) and combines this with presences and the environmental predictors to create a dataset that is ready to be input into the SDM model. The pipeline runs the SDM on this data using the MaxEnt algorithm using the ENMeval R package (Kass et al. 2021). The MaxEnt SDM is run by 1\) partitioning occurrence and background points into subsets for training and evaluation, 2\) building the model with different algorithmic settings (model tuning), and 3\) evaluating their performance ([see package vignette](https://jamiemkass.github.io/ENMeval/articles/ENMeval-2.0-vignette.html#partition)). Lastly, the pipeline computes the 95% confidence interval using bootstrapping and cross validation techniques.

**BON in a Box pipeline:**

The BON in a Box pipeline allows you to run an SDM for a specific region and species (or multiple species) of interest. The pipeline has the following inputs:

* **Taxa list:** The user can specify the species (or multiple species) they are interested in.   
* **Bounding box:** The user can specify the bounding box where they want to distribution to be predicted (units must be in the chosen CRS).  
* **Projection system:** The user can specify a projection system.  
* **Data source:** The user can pull species’ occurrences using the GBIF API or from GBIF on the planetary computer.  
* **Environmental layers:** The user specifies the environmental layers that they want to include in the species distribution model, pulled from a STAC catalog.  
* **Minimum and maximum year:** The user can specify the year range for which they want to pull GBIF observations.  
* **Method background:** The user chooses a method to sample background points (pseudo absences) from a drop down menu  
* **Number of background points:** The user specifies the number of background points to choose  
* **Number of runs:** The number of SDMs to run to compute the 95% confidence interval through cross validation.  
* **Partition type:** The user can choose a method for partitioning the occurrence and background data into subsets for training and evaluation from a dropdown menu  
  * Block \- partitions the bounding box into four equally sized quadrants and assigns groups by quadrant  
  * Checkerboard 1 \- Generates checkerboard from the study area and assigns groups based on what square the points fall in  
  * Checkerboard 2- Similar to checkerboard 1 but performs this separately for occurrence and background points  
  * Jackknife \- Does not partition the background points into testing and training (uses them all), performs leave one out cross validation (recommended for small datasets only)  
  * Random k-fold \-  Does not partition the background points into testing and training, partitions groups randomly into a user specified (K) number of bins, and runs the model k times, with each bin used once as testing.  
* **Mask:** If the user is only interested in a specific country or study area, they can upload a polygon and the pipeline will crop the results to only that area.  
* **Spatial resolution:** The spatial resolution at which to predict the SDMs.

The pipeline creates the following outputs:

* **DOI of GBIF download:** Generates a DOI of the GBIF download for reproducibility.  
* **Presences:** GBIF presences can be viewed on a map.  
* **Environmental Predictors:** All environmental layers can be viewed separately as rasters.  
* **Predictions:** SDM prediction probabilities can be viewed as a raster.  
* **Variability of predictions:** The variability of the 95% confidence of each prediction can be viewed on a map to show uncertainty.

**Contributors:**

* [Sarah Valentin](https://orcid.org/0000-0002-9028-681X)  
* [Guillaume Larocque](https://orcid.org/0000-0002-5967-9156)
* [François Rousseu](https://orcid.org/0000-0002-2400-2479)

**Citations:** 

Elith, J., & Leathwick, J. R. (2009). Species Distribution Models: Ecological Explanation and Prediction Across Space and Time. Annual Review of Ecology, Evolution, and Systematics, 40(Volume 40, 2009), 677–697. https://doi.org/10.1146/annurev.ecolsys.110308.120159

Kass JM, Muscarella R, Galante PJ, Bohl CL, Pinilla-Buitrago GE, Boria RA, Soley-Guardia M, Anderson RP (2021). “ENMeval 2.0: Redesigned for customizable and reproducible modeling of species’ niches and distributions.” Methods in Ecology and Evolution, 12(9), 1602-1608. https://doi.org/10.1111/2041-210X.13628.

Peterson, A. T. (2001). Predicting Species’ Geographic Distributions Based on Ecological Niche Modeling. The Condor, 103(3), 599–605. [https://doi.org/10.1093/condor/103.3.599](https://doi.org/10.1093/condor/103.3.599)
