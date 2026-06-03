_Author(s): Francis van Oordt

Reviewed by: Reviewer names

## Introduction

Biodiversity monitoring often requires researchers to draw samples of different population due to limitation of budget, time, and accesibility. Many methods exist to produce samples from a continous surface, but balanced sampling has proven to be one of the most efficient in capturing patterns in different populations. Often, researchers aim to prioritize sampling based on different parameters, one being environmental characteristics of their study region (as a proxy of biomes or ecological regions). Tools that allow for quick and robust sampling frameworks provide researchers with strong sampling designs to address multiple ecological questions.

Here we present a method that uses balanced acceptance sampling to randomly select sampling sites in a defined area, and allows for the prioritization of environmentally different regions within the study area.
## Uses
Selection of sampling sites using a BAS algorithm with two different approches (equal and unequal sampling distribution).

In a first step, the pipeline produces environmental blocks based on user defined environmental variables (after performing a PCA analysis on said variables and defining a block grid) and can use those blocks to generate an unequal sampling distribution.

Blocks are created from PCAs performed on the selected environmental variables or can use only two raw environmental variables, in which case no PCA is performed.

The user must define the grid size for block generation and specify a target sample size to be allocated using a randomly balanced design. When the “unequal” option is selected, the inclusion probability of each block is proportional to its area, ensuring that larger blocks have a higher chance of being sampled.

Alternatively, an equal sampling distribution can be selected, where all blocks have the same probability of selection. The procedure will also plot the randomly selected sampling points over the environmental blocks, allowing users to visually assess whether certain areas are underrepresented or missing from the random sampling pattern.

## Pipeline limitations
Pipeline was designed to work for a defined geopolitical outline (e.g. country, or province), have not tested rectangular extends.
Unequal sampling may produce unexpected results in the balanced approach.

## Before you start
Define a projected CRS for your study area
Select environmental variables that may be of ecological importance for your study
Define how many environmental blocks you expect to produce (too many may be noisy, to little may be underrepresenting the environmental diversity).

## Running the pipeline

### *For example:*
### Pipeline inputs

- **Bounding box and CRS:** *description of input 1 and what it means.*

- **Environmental variables (STAC collection items):** Set of environmental variables to use  (e.g. for temperature "chelsa-clim|bio1", precipitation "chelsa-clim|bio12"), on which to run the PCA (a minimum of 2 variables are needed). Environmental variables must be continuous values.

- **Sampling type:** Select and option between equal BAS or unequal probability BAS. "Equal" will not consider the blocks and place all sampling randomly in the whole study area.  "Unequal" will take into account the size of the each environmental block and redistribute the sampling sites based on the size of block.  

- **Target total sites:** A number of target sampling sites to obtain with the algorithm. The researcher should be aware of this requirement and the total extent of the area to cover before deciding a final mumber of sites.

- **Number of columns:** Number of columns  for the environmental space grid (together with rows will define the final number environmental blocks). Start with as small even number of columns and row, as increasing blocks will create greater unnecessary variability. 

- **Number of rows:** Number of rows for the environmental space grid (together with columns will define the final number environmental blocks).  Start with as small even number of columns and row, as increasing blocks will create greater unnecessary variability. 

- **Spatial resolution:** Integer, spatial resolution of the rasters in the same units as the coordinate reference system (meters for projected reference systems and degrees for reference systems in lat long). This input may be blank when using ESPG:4326.

### Pipeline outputs

- **Environmental blocks raster:** Raster file of the study area with the environmental blocks as categorical classes  
- **Summary of PCA:** Principal component analysis summary for the environmental variables included in the analysis

- **Blocks and map plots:** Blocks showing the PCA 1 and 2 result and the predefined blocks dividing the environmental space and the map of the environmental blocks in geographic space

- **Maps output:** Maps of study area with selected sampling points only (no environmental blocks) and also including the environmental blocks.

- **Environmental Rasters:** Array of environmental rasters (for exploration only)

- **Selected points:** dataframe of selected points

- **selected points shapefile:** Vector shapefile of selected points




## Example

## Troubleshooting

**Common errors:**

- `Error 1`: *description*
- `Error 2`: *description*


## References
spbal: Spatially Balanced Sampling Algorithms
10.32614/CRAN.package.spbal
Survey-gap analysis in expeditionary research: where do we go from here?
https://doi.org/10.1111/j.1095-8312.2005.00520.x
Selection of sampling sites for biodiversity inventory: Effects of environmental and geographical considerations
https://doi.org/10.1111/2041-210X.13869

