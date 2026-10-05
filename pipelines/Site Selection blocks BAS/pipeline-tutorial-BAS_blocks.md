_Author(s): Francis van Oordt, Samara Manzin_

## Introduction

  Biodiversity monitoring requires sampling designs that make effective use of
  limited time, budgets, and field access. Balanced Acceptance Sampling (BAS)
  selects sampling sites distributed across a study area using a spatially
  balanced random design.
  Often, researchers aim to prioritize sampling based on 
  different parameters, one being environmental characteristics of their study
  region (as a proxy of biomes or ecological regions). Tools that allow for
  quick and robust sampling frameworks provide researchers with strong sampling
  designs to address multiple ecological questions. 

  This pipeline combines BAS with environmental blocks derived from
  user-selected environmental variables. These blocks group locations with
  similar environmental conditions and help users assess how well the selected
  sites cover the study area’s environmental variation.  

## Uses

  Use this pipeline to generate new sampling locations within a study area and
  examine their distribution across environmental conditions.

  The pipeline first performs a principal component analysis (PCA) on the
  selected environmental variables. It divides the space defined by the first
  two principal components into a grid and assigns each raster cell to an
  environmental block. Locations in the same block have similar values along
  these two environmental gradients, but may occur in separate geographic
  areas. 
  
  The pipeline offers two sampling options:

  - **Equal:** Selects sites using equal-probability BAS across the study
  polygon. Environmental blocks are used to visualize coverage and do not affect
  site selection.

  - **Unequal:** Generates BAS candidate sites and filters them using weights
  derived from the environmental blocks. The current implementation uses the
  logarithm of the number of raster cells in each block, giving candidates in
  larger blocks higher acceptance weights.

  Both options produce maps of the selected sites, including a map overlaid on
  the environmental blocks. These maps can help identify environmental
  conditions that received few or no sampling sites.


## Pipeline limitations

  * Currently the pipeline only works for a defined geopolitical outline (e.g.
  country, or province). 

  * Environmental blocks reflect variation in the selected environmental variables. They should not be interpreted as validated biomes or ecological regions.

  * Blocks use only the first two principal components. Check the PCA summary to assess how much environmental variation these components explain.

  * Unequal sampling does not guarantee equal representation of environmental blocks or preferential sampling of rare environmental conditions. Review the selected sites and their environmental coverage before using the results.

  * The unequal option uses a fixed pool of 10,000 candidate sites. If too few candidates pass the filtering step, the requested number of valid sites may not be obtained.

  * Site selection does not account for field accessibility, land ownership, or logistical constraints.


## Before you start
  * Define a projected CRS for your study area 

  * Select environmental variables that may be of ecological importance for your
  study 

  * Define how many environmental blocks you expect to produce (too many may be
  noisy, to little may be underrepresenting the environmental diversity). 

## Running the pipeline

### Pipeline inputs

- **Bounding box and CRS:** Select a country/region and a CRS to obtain the associated bounding box.

- **Spatial resolution:** Integer, spatial resolution of the rasters in the same units as the coordinate reference system (meters for projected reference systems and degrees for reference systems in lat long). This input may be blank when using ESPG:4326.

- **Environmental variables (STAC collection items):** Provide at least two continuous environmental raster variables, using the format `collection|item`, such as `chelsa-clim|bio1` and `chelsa-clim|bio12`. The pipeline performs PCA on these variables to create the environmental blocks.

- **Sampling type:** Select and option between equal BAS or unequal probability BAS. "Equal" will not consider the blocks and place all sampling randomly in the whole study area.  "Unequal" will take into account the size of the each environmental block and redistribute the sampling sites based on the size of block.  

- **Target total sites:** A number of target sampling sites to obtain with the algorithm. The user must decide on a number of sites based on their sampling goals and scale of the study. 

Larger study areas should have greater number of sampling locations, but constraints exist (e.g budget, staff, etc.) that may limit sampling locations and coverage. 

Researchers should take into account their specifics sampling goals and timelines, and proceed with caution. 

- **Number of columns:** Number of columns for the environmental space grid (together with rows will define the final number of environmental blocks). 

Blocks are based on a PCA of the environmental variables selected and represent  a proxy of ecozones in areas with lacking information. 

A general recommendation is to start with fewer blocks because it would simplify computation and understanding of the study region, 5-10 blocks, and later increase if needed.

- **Number of rows:** Number of rows for the environmental space grid (together with columns will define the final number environmental blocks). 

Blocks are based on a PCA of the environmental variables selected and represent  a proxy of ecozones in areas with lacking information. 

A general recommendation is to start with fewer blocks because it would simplify computation and understanding of the study region, 5-10 blocks, and later increase if needed.

### Pipeline Steps

#### 1. Retrieve environmental data 
Load the selected environmental rasters and the study-area polygon.
#### 2. Create environmental blocks 
Aggregate and mask the rasters, perform PCA, and divide the first two principal components into the requested grid.
#### 3. Select sampling sites 
Apply equal BAS or the block-weighted unequal sampling procedure.
#### 4. Review and export results
Inspect the maps and download the environmental blocks, PCA summary, and selected-site files.

### Pipeline outputs

- **Environmental blocks raster:** Raster file of the study area with the environmental blocks as categorical classes  

- **Summary of PCA:** Principal component analysis summary for the environmental variables included in the analysis

- **Blocks and map plots:** Blocks showing the PCA 1 and 2 result and the predefined blocks dividing the environmental space and the map of the environmental blocks in geographic space

- **Maps output:** Maps of study area with selected sampling points only (no environmental blocks) and also including the environmental blocks.

- **Environmental Rasters:** Array of environmental rasters (for exploration only)

- **Selected points:** Dataframe of selected points

- **selected points shapefile:** Vector shapefile of selected points

## References
spbal: Spatially Balanced Sampling Algorithms
10.32614/CRAN.package.spbal
Survey-gap analysis in expeditionary research: where do we go from here?
https://doi.org/10.1111/j.1095-8312.2005.00520.x
Selection of sampling sites for biodiversity inventory: Effects of environmental and geographical considerations
https://doi.org/10.1111/2041-210X.13869

