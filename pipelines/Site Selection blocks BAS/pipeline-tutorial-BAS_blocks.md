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

  Use this pipeline when planning a new monitoring network and exploring how proposed sampling locations cover different environmental conditions.

- **Equal sampling:** Use this option when you want equal-probability sampling across the study area. The environmental-block map helps you inspect which environmental conditions are represented by the proposed sites.

- **Unequal sampling:** Use this option when you want site selection to give greater weight to environmental blocks containing more raster cells. This option does not specifically prioritize rare environmental conditions or give every block equal representation.

Review the proposed locations alongside information about access, land ownership, and field conditions before planning visits. Moving or replacing sites can affect the statistical properties of the sampling design.


## Pipeline limitations

  * Currently the pipeline only works for a defined geopolitical outline (e.g.
  country, or province). 

  * Environmental blocks reflect variation in the selected environmental variables. They should not be interpreted as validated biomes or ecological regions.

  * Blocks use only the first two principal components. Check the PCA summary to assess how much environmental variation these components explain.

  * Unequal sampling does not guarantee equal representation of environmental blocks or preferential sampling of rare environmental conditions. Review the selected sites and their environmental coverage before using the results.

  * The unequal option uses a fixed pool of 10,000 candidate sites. If too few candidates pass the filtering step, the requested number of valid sites may not be obtained.

  * Site selection does not account for field accessibility, land ownership, or logistical constraints.


## Before you start
- Select at least two continuous environmental variables relevant to your monitoring objectives.

- Choose an initial target number of sampling sites based on your objectives and field resources.

## Running the pipeline

### Pipeline inputs

- **Bounding box and CRS:** elect your country or region of interest, then choose a projected coordinate reference system (CRS) appropriate for the study area using the dropdown.

- **Spatial resolution:** Integer, spatial resolution of the rasters in the same units as the coordinate reference system (meters for projected reference systems and degrees for reference systems in lat long). This input may be blank when using ESPG:4326.

- **Environmental variables (STAC collection items):** Provide at least two continuous environmental raster variables, using the format `collection|item`, such as `chelsa-clim|bio1` and `chelsa-clim|bio12`. The pipeline performs PCA on these variables to create the environmental blocks.

- **Sampling type:** Select and option between equal BAS or unequal probability BAS. "Equal" will not consider the blocks and place all sampling randomly in the whole study area.  "Unequal" will take into account the size of the each environmental block and redistribute the sampling sites based on the size of block.  

- **Target total sites:** A number of target sampling sites to obtain with the algorithm. The user must decide on a number of sites based on their sampling goals and scale of the study. 

Larger study areas should have greater number of sampling locations, but constraints exist (e.g budget, staff, etc.) that may limit sampling locations and coverage. 

Researchers should take into account their specifics sampling goals and timelines, and proceed with caution. 

- **Number of rows and columns:** These inputs divide the environmental space into a grid. Rows multiplied by columns gives the maximum number of blocks; some grid cells may contain no environmental data. For an initial exploratory run, 3 rows and 3 columns gives up to 9 blocks. Inspect the results before increasing the grid detail. The pipeline does not determine the block count from the geographic size of the study area.


### Pipeline steps

#### 1. Retrieve environmental data 
Load the selected environmental rasters and the study-area polygon.
#### 2. Create environmental blocks 
Aggregate and mask the rasters, perform PCA, and divide the first two principal components into the requested grid.
#### 3. Select sampling sites 
Apply equal BAS or the block-weighted unequal sampling procedure.
#### 4. Review and export results
Inspect the maps and download the environmental blocks, PCA summary, and selected-site files.

### Pipeline outputs

- **Environmental blocks raster:** A categorical GeoTIFF identifying the environmental block assigned to each classified raster cell.

- **Summary of PCA:** A CSV showing the standard deviation, percentage of variance explained, and cumulative percentage of variance explained for the principal components. Use it to assess how much environmental variation the first two components represent.

- **Blocks and map plots:** A figure showing environmental blocks in principal-component space alongside their geographic distribution.

- **Maps output:** Two maps showing the proposed sampling sites: one over the study-area polygon and one over the environmental blocks. Use these to inspect geographic and environmental coverage.

- **Environmental rasters:** The environmental rasters retrieved for the analysis, provided for inspection and further exploration.

- **Selected points:** A CSV containing the proposed sites’ longitude and latitude in WGS84 (EPSG:4326), with columns named lon and lat.

- **Selected points GeoJSON:** A GeoJSON file containing the proposed sampling locations in WGS84 (EPSG:4326).

## References
[spbal: Spatially Balanced Sampling Algorithms](https://cran.r-project.org/web/packages/spbal/index.html)
Survey-gap analysis in expeditionary research: where do we go from here?
https://doi.org/10.1111/j.1095-8312.2005.00520.x
Selection of sampling sites for biodiversity inventory: Effects of environmental and geographical considerations
https://doi.org/10.1111/2041-210X.13869

