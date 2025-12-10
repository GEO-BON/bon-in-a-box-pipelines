Author(s): Michael D. Catchen

Reviewed by: 

Review status: Under review

## Introduction
This pipeline builds a model to predict the distribution of a species (a type of
essential biodiversity variable), by using occurrence data from the Global
Biodiversity Information Facility (GBIF), and environmental predictors from an
arbitrary STAC Catalogue.

In particular, this pipeline uses a specific model called a Boosted Regression
Tree (BRT), a machine-learning model which tends to work well with spatial data.

### What is a boosted regression tree?

#### Species Distribution Modeling as a Classification Problem

To make an SDM using BRTs, we need a set of species presences and absences, In this context, we ideally have _true_ absences, but we can use pseudoabsences instead. Each instance of a presence/absence is denoted $y_i$ and called a _label_, where

$$y_i = \begin{cases} 1 \quad&\text{if present} \\0 &\text{if absent}\end{cases}$$

Each $y_i$ is associated with environmental data $\vec{x}_i$, called _features_, at the location where $y_i$ was recorded. Given a set of $n$ data points, $\mathbf{X} = (x_1, x_2, \dots, x_n)$, $\mathbf{y} =(y_1, y_2, \dots, y_n)$, we split the data into _training_ and _test_ sets, fit the model on the _train_ set, and evaluated the model performance on the _test_ set.

#### What is a decision tree?

A decision tree (DT) is a machine learning (ML) model for supervised learning, meaning it takes an input vector $\vec{x}$ to produce an output $y$. DTs can be used either for _regression_, where the output is _continuous_ (and potentially multivariate), or classification, where the output is discrete. In our case, the goal of our SDM is to predict an output score for species occurrence for environmental features $\vec{x}_i$ at each location. 

A DT works by considering a set of _binary_ decision rules, starting at the root
of the tree and following a path, based on the values of input features
$\vec{x}_i$. For an example, consider the tree below for a three-dimensional
input $\vec{x} = (x_1, x_2, x_3)$ 

For example, for the input $\vec{x} = (0.34, 0.62, 0.43)$, if we follow the path in the tree, we get an output predicted score of $p_i = 0.17$. 

Decision trees in their simplest form (as described above), are not commonly used in modern ML, instead there are improvements that can be made 

#### Bootstrap Aggregation ("Bagging")

An early method to improve the performance of decision trees is to use _bootstrap aggregation_ (often shorted to _bagging_). The idea of bagging is to take the $t_m$ points of _training data_ $\mathbf{\tilde{y}} = (y_{a}, y_{b}, \dots, y_{c})$ and fit _many_ decision trees on _subsets_ of the training data, and use an average of the prediction from each tree to produce an _ensemble model_.

A common form of bagging is the use of _Random Forests_ (RFs). In addition to
bagging, RFs use a _subset_ of features of each tree, for example if each input
feature has dimension $n_f$, a common choice is to select $\sqrt{n_f}$  features
for each tree in the random forest. 

#### Gradient Boosting 

[Gradient boosting](https://en.wikipedia.org/wiki/Gradient_boosting) is a method for improving _ensemble model_ predictions by reweighing the importance of each model using [gradient-descent](https://en.wikipedia.org/wiki/Stochastic_gradient_descent) optimization to improve performance.


#### How do we get uncertainty from BRTs (and why do we want it)?

Boosted Regression Trees combine gradient boosting with _Random Forest_ style bagging.  

#### Including uncertainty in BRTs using Gaussian Maximum Likelihood for Splits

We can associated uncertainty with the predictions made using a BRT by using [maximum likelihood estimation (MLE)](https://en.wikipedia.org/wiki/Maximum_likelihood_estimation) to estimate the values of the splits. We do this using the `GaussianMLE` loss function in [EvoTrees.jl](https://github.com/Evovest/EvoTrees.jl/blob/4caa1269e1a663830887e248e980dc63494dfe3e/src/loss.jl#L87 ),  For example, if each rule $j$ of the decision tree has the from $x_i > \alpha_j$ , the value of $\alpha_j$ is inferred by [Gaussian MLE](http://jrmeyer.github.io/machinelearning/2017/08/18/mle.html), where the true value of $\alpha_j \sim \mathcal{N}(\mu_j, \sigma_j)$. This means for a fitted tree, we can infer the uncertainty associated with each set of input features $\vec{x}_i$  by summing up the $\sigma_j$ values at each decision rule $j$ in the tree that each input feature goes through on the way to an output score $p_i$.


## Uses
BRT species distribution models can be used as input layers for other pipelines that require species ranges (e.g. the Species Habitat Index) or stacked together to create maps of species richness. Uncertaintly layers from these SDMs can be used to prioritize sampling areas (e.g. through the occurrence sampling priority pipeline).

## Pipeline limitations
- The pipeline needs a minimum number of occurrences. If there are too few occurrences the model will not generate accurate predictions.
- If there are a ton of occurrences, pseudoabsence generation will be slow. Make sure that the maximum candidate number of pseudoabsences is appropriate for the size of the input rasters. Pseudoabsences should not be too sparse compared to your occurrences.
- Do not transform variables (e.g. PCA) before inputting into the pipeline. 

## Before you start
A GBIF API key is needed for this analysis. Learn more [here](https://techdocs.gbif.org/en/openapi/).

## Running the pipeline

### Pipeline inputs

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


### Pipeline outputs

- **Predicted SDM**: map of the predicted occurrence score at each location
- **SDM Uncertainty**: map of relative uncertainty of the SDM at each location
- **Fit Statistics**: describes different metrics of how
  good the model is on the test set
- **Pseudoabsences**: generated locations where species is assumed to not occur,
  based on hueristics.
- **Range Map**: species range, computed by thresholding the predicted SDM at
  the optimum threshold (defined as the threshold the maximizes the Matthew's
  Correlation Coefficient)
- **Environment Space**: diagnostic **corners plot** of the locations of occurrences and
  pseudoabsences in environmetal space
- **Tuning Curve**: diagnostic **tuning curve** plot of the value of the Matthew's Correlation
  Coefficient across various thresholding values between 0 and 1.
- **Presences**: cleaned occurrence data after cleaning
- **DOI of GBIF download**

## Example
See an example output [here](https://pipelines-results.geobon.org/viewer/SDM%3ESDM_BRT%3E933ca049e112ab67db9711517e6ee30a)

## Troubleshooting
For other errors, see the EvoTrees (BRT in Julia) package documentation [here](https://evovest.github.io/EvoTrees.jl/dev/) or speciesDistributionToolkit documentation [here](https://poisotlab.github.io/SpeciesDistributionToolkit.jl/v1.7.2/).

**Common errors:**

- `iltering > Clean Coordinates": cannot derive coordinates from non-numeric matrix`: The pipeline will break if there are no occurrences of the chosen species in the choesen bounding box or time frame. Check logs to make sure.

## References
Elith, J., Leathwick, J.R. and Hastie, T. (2008), A working guide to boosted regression trees. Journal of Animal Ecology, 77: 802-813. https://doi.org/10.1111/j.1365-2656.2008.01390.x

Poisot, T.; Bussières-Fournel, A.; Dansereau, G.; Catchen, M. D. A Julia toolkit for species distribution data. Peer Community Journal, Volume 5 (2025), article no. e101. https://doi.org/10.24072/pcjournal.589

