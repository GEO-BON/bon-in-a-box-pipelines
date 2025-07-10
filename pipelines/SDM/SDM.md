Species distributions are an important EBV in the ‘species populations’ class. Knowing where species are is essential for understanding biodiversity patterns and informing conservation efforts. However, less than 10% of the world is well sampled, and even the longest running and well-sampled biodiversity observation networks have substantial data gaps. Information on species occurrences is often sparse and heavily spatially and taxonomically biased, necessitating the need for species distribution models (SDMs) to fill these data gaps and provide a better, less biased idea of where species are. SDM outputs be used as key base layers for a wide variety of purposes including: creating maps for sampling prioritization, quantifying the impact of environmental stressors on species, mapping habitat suitability for at-risk species, mapping biodiversity hotspots across the landscape, identifying the locations of conservation priorities and protected area expansion, identifying sampling gaps and the needed locations of future sampling, and calculating a range of biodiversity indicators including the Species Habitat Index (SHI), the Species Protection Index (SPI)

### **MaxEnt**

**Methods:**

SDMs predict where species are likely to occur based on a suite of environmental variables that are associated with known occurrences (Peterson, 2001; Elith and Leathwick, 2009). The MaxEnt pipeline pulls occurrences of the species of interest from GBIF and environmental raster layers from the GEO BON STAC catalog. Then, the pipeline cleans the GBIF data by only including one occurrence per pixel and removes collinearity between the environmental layers. Third, the pipeline creates a set of pseudo-absences (background points) and combines this with presences and the environmental predictors to create a dataset that is ready to be input into the SDM model. The pipeline runs the SDM on this data using the MaxEnt algorithm using the ENMeval R package (Kass et al. 2021). The MaxEnt SDM is run by 1\) partitioning occurrence and background points into subsets for training and evaluation, 2\) building the model with different algorithmic settings (model tuning), and 3\) evaluating their performance ([see package vignette](https://jamiemkass.github.io/ENMeval/articles/ENMeval-2.0-vignette.html#partition)). Lastly, the pipeline computes the 95% confidence interval using bootstrapping and cross validation techniques.

**BON in a Box pipeline:**

The BON in a Box pipeline allows you to run an SDM for a specific region and species (or multiple species) of interest. The pipeline has the following inputs:

- **Taxa list:** The user can specify the species (or multiple species) they are interested in.
- **Bounding box:** The user can specify the bounding box where they want to distribution to be predicted (units must be in the chosen CRS).
- **Projection system:** The user can specify a projection system.
- **Data source:** The user can pull species’ occurrences using the GBIF API or from GBIF on the planetary computer.
- **Environmental layers:** The user specifies the environmental layers that they want to include in the species distribution model, pulled from a STAC catalog.
- **Minimum and maximum year:** The user can specify the year range for which they want to pull GBIF observations.
- **Method background:** The user chooses a method to sample background points (pseudo absences) from a drop down menu
- **Number of background points:** The user specifies the number of background points to choose
- **Number of runs:** The number of SDMs to run to compute the 95% confidence interval through cross validation.
- **Partition type:** The user can choose a method for partitioning the occurrence and background data into subsets for training and evaluation from a dropdown menu
  - Block \- partitions the bounding box into four equally sized quadrants and assigns groups by quadrant
  - Checkerboard 1 \- Generates checkerboard from the study area and assigns groups based on what square the points fall in
  - Checkerboard 2- Similar to checkerboard 1 but performs this separately for occurrence and background points
  - Jackknife \- Does not partition the background points into testing and training (uses them all), performs leave one out cross validation (recommended for small datasets only)
  - Random k-fold \- Does not partition the background points into testing and training, partitions groups randomly into a user specified (K) number of bins, and runs the model k times, with each bin used once as testing.
- **Mask:** If the user is only interested in a specific country or study area, they can upload a polygon and the pipeline will crop the results to only that area.
- **Spatial resolution:** The spatial resolution at which to predict the SDMs.

The pipeline creates the following outputs:

- **DOI of GBIF download:** Generates a DOI of the GBIF download for reproducibility.
- **Presences:** GBIF presences can be viewed on a map.
- **Environmental Predictors:** All environmental layers can be viewed separately as rasters.
- **Predictions:** SDM prediction probabilities can be viewed as a raster.
- **Variability of predictions:** The variability of the 95% confidence of each prediction can be viewed on a map to show uncertainty.

[See an example output here](https://pipelines-results.geobon.org/viewer/SDM%3ESDM_maxEnt%3E78ed53b7ea6b96ef58008075a4dfb487)

**Contributors:**

- [Sarah Valentin](https://orcid.org/0000-0002-9028-681X)
- [Guillaume Larocque](https://orcid.org/0000-0002-5967-9156)
- [François Rousseu](https://orcid.org/0000-0002-2400-2479)

**Citations:**

Elith, J., & Leathwick, J. R. (2009). Species Distribution Models: Ecological Explanation and Prediction Across Space and Time. Annual Review of Ecology, Evolution, and Systematics, 40(Volume 40, 2009), 677–697. https://doi.org/10.1146/annurev.ecolsys.110308.120159

Kass JM, Muscarella R, Galante PJ, Bohl CL, Pinilla-Buitrago GE, Boria RA, Soley-Guardia M, Anderson RP (2021). “ENMeval 2.0: Redesigned for customizable and reproducible modeling of species’ niches and distributions.” Methods in Ecology and Evolution, 12(9), 1602-1608. https://doi.org/10.1111/2041-210X.13628.

Peterson, A. T. (2001). Predicting Species’ Geographic Distributions Based on Ecological Niche Modeling. The Condor, 103(3), 599–605. [https://doi.org/10.1093/condor/103.3.599](https://doi.org/10.1093/condor/103.3.599)

### **Boosted Regression Trees**

This document describes the methodology behind the BON-in-a-Box (BiaB) pipeline for using Boosted Regression Trees (BRTs) for species distribution modeling.

**Summary**

This pipeline builds a model to predict the distribution of a species (a type of
essential biodiversity variable), by using occurrence data from the Global
Biodiversity Information Facility (GBIF), and environmental predictors from an
arbitrary STAC Catalogue.

In particular, this pipeline uses a specific model called a Boosted Regression
Tree (BRT), a machine-learning model which tends to work well with spatial data. The
details of how a BRT works are in the description of the key script in the
pipeline, [`fitBRT.jl`](../../scripts/SDM/BRT/fitBRT.md).

**Inputs**:

- **Species**: The name of the taxon the build a species distribution model for
- **Environmental Predictors**: The set of environmental predictors to use
- **Coordinate Reference System**: The coordinate reference system to use for the analysis
- **Bounding Box**: The bounding box for the analysis, given in the same coordinate
  reference system as listed above
- **GBIF Data Source**: the source of GBIF data to use
- **Start Year**: the earliest year to select occurrences from
- **End Year**: the final year to select occurrences from
- **Spatial Resolution**: the spatial resolution of the analysis in meters
- **Mask**: a mask of regions to ignore
- **STAC URL**: the URL to the STAC catalogue where the environmental predictors are hosted

**Outputs**

- **Predicted SDM**: map of the predicted occurrence score at each location
- **SDM Uncertainty**: map of relative uncertainty of the SDM at each location
- **Fit Statistics**: describes different metrics of how
  good the model is on the test set
- **Pseudoabsences**: generated locations where species is assumed to not occur,
  based on hueristics.

[See an example pipeline output here](https://pipelines-results.geobon.org/viewer/SDM%3ESDM_BRT%3Ed519bfe0fa3489f28738763dced7ceb0)

> [!IMPORTANT]  
> Using BRTs to fit a species distribution model requires _absence data_. For the majority of species where no absence data is available, there are various methods to generate pseudoabsences (PAs) based on heuristics about species occurrence. However, the performance characteristics of an SDM fit using PAs can be widely variable depending on the method and parameters used to generate PAs. This means the results of BRT should be explicitly considered as a function of how PAs were generated, and sensitivity analysis to different PAs is _highly_ encouraged.

- **Range Map**: species range, computed by thresholding the predicted SDM at
  the optimum threshold (defined as the threshold the maximizes the Matthew's
  Correlation Coefficient)
- **Environment Space**: diagnostic **corners plot** of the locations of occurrences and
  pseudoabsences in environmetal space
- **Tuning Curve**: diagnostic **tuning curve** plot of the value of the Matthew's Correlation
  Coefficient across various thresholding values between 0 and 1.
- **Presences**: cleaned occurrence data after cleaning
- **DOI of GBIF download**

**Pipeline Steps**

```mermaid
flowchart LR
    a{input species} --> b[Load GBIF Occurrences]
    c{input bounding box} --> b
    d{input layers} --> e[Load Layers from STAC]
    c --> e
    b --> f[Clean presences]
    f --> g[Generate Pseudoabsences]
    c --> g
    g --> h[Fit BRT]
    e --> h
    h --> i(predicted sdm)
    h --> j(uncertainty map)
    c --> k[create water mask]
    h --> l[model fit statistics]
    h --> m[diagnostic plots]
    k --> h
```

### **ewlgcpSDM (mapSpecies)**

**Methods:**
The species distribution modeling method provided in the package ewlgcpSDM (Effort-Weighted Log-Gaussian Cox Process) is based on spatial point processes and presence-only observations. It implements the method proposed by Simpson et al. (2016) to estimate log-Gaussian Cox processes using INLA (Rue et al. 2009) and the SPDE approach (Lindgren et al. 2009). The model relies on a discrete grid (the mesh) of arbitrary resolution to approximate the spatial component of the model. The method proposed in ewlgcpSDM contains three key aspects for species distribution modeling, namely:

- a spatial component that can help in accounting for variation in relative intensities not explained by predictors
- an effort-weighted adjustment analogous to target-group background selection (Phillips et al. 2009)
- a suit of model-based prediction uncertainty layers thanks to the bayesian approach used by INLA

The current version of the pipeline does not make use of the spatial component yet as some more work is needed to allow the adjustments necessary for the spatial component to work properly. The current version of the pipeline thus corresponds to an effort-weighted inhomogeneous Poisson point process.

**BON in a Box pipeline:**
The pipeline is used to run an SDM for a set of species in a specific region and using a set of environmental predictors. Some inputs are yet to be added to the list of inputs required by the user. Currently, the pipeline mostly reuses the same inputs as the MaxEnt pipeline, namely:

- **Taxa list:** The user can specify the species (or multiple species) they are interested in.
- **Bounding box**: The user can specify the bounding box where they want to distribution to be predicted (units must be in the chosen CRS).
- **Projection system**: The user can specify a projection system.
- **Data source**: The user can pull species’ occurrences using the GBIF API or from GBIF on the planetary computer.
- \*\*Environmental layers: The user specifies the environmental layers that they want to include in the species distribution model, pulled from a STAC catalog.
- **Minimum and maximum year**: The user can specify the year range for which they want to pull GBIF observations.
- **Method background**: The user chooses a method to sample background points (pseudo absences) from a drop down menu
- **Number of background points**: The user specifies the number of background points to use
- **Number of blocks**: The number of cross-validation blocks used to compute predictive performance metrics (not implemented yet).
- **Mask**: If the user is only interested in a specific country or study area, they can upload a polygon and the pipeline will crop the results to only that area.
- **Spatial resolution**: The spatial resolution of the predictors used

The pipeline creates the following outputs:

- **Predictions**: model intensity predictions (analogous to relative densities)
- **Species list:** a list of species for which the model was run
- **Presences:** GBIF observations used for the model
- **Uncertainty:** a list of raster layers with model outputs and uncertainties (e.g. 95% credible interval, standard deviation, spatial component, etc.)
- **CI range:** difference between the upper (0.975) and the lower (0.025) credible interval bound
- **Environmental predictors:** layers used as predictors
- **Background:** background points used for the effort weighting
- **Dmesh:** dual mesh used by the sdm model (INLA mesh)
- **DOI of GBIF download:** Used for citing downloaded data.

[See an example pipeline output here](https://pipelines-results.geobon.org/viewer/SDM%3ESDM_ewlgcp%3Edfbdc18c5e923c2a9fa426efc502843c)

**Contributors:**

- François Rousseu (https://orcid.org/0000-0002-2400-2479)
- Guillaume Blanchet (https://orcid.org/0000-0001-5149-2488)
- Dominique Gravel (https://orcid.org/0000-0002-4498-7076)

**Citations:**
Lindgren, F., Rue, H., and Lindström, J. 2011. An explicit link between Gaussian fields and Gaussian Markov random fields: the stochastic partial differential equation approach. Journal of the Royal Statistical Society Series B: Statistical Methodology, 73(4): 423-498.

Phillips, S. J., Dudík, M., Elith, J., Graham, C. H., Lehmann, A., Leathwick, J. and Ferrier, S. 2009. Sample selection bias and presence-only distribution models: implications for background and pseudo-absence data. Ecological Applications, 19(1): 181-197, https://doi.org/10.1890/07-2153.1

Rue, H., Martino, S. and Chopin, N. 2009. Approximate Bayesian Inference for Latent Gaussian models by using Integrated Nested Laplace Approximations, Journal of the Royal Statistical Society Series B: Statistical Methodology, 71(2): 319–392, https://doi.org/10.1111/j.1467-9868.2008.00700.x

Simpson, D., Illian, J. B., Lindgren, F., Sørbye, S. H. and H. Rue. 2016. Going off grid: computationally efficient inference for log-Gaussian Cox processes, Biometrika 103(1): 49–70, https://doi.org/10.1093/biomet/asv064
