_Authors: Francis van Oordt, Samara Manzin_

## Introduction

Biodiversity monitoring programmes may need to expand their sampling network or revisit sites that are no longer regularly monitored. Choosing additional sites can help improve coverage of environmental conditions and geographic areas that are poorly represented by the current network.

This pipeline uses a stepwise p-median optimization procedure implemented in the SURDES package to select additional sites from a user-provided candidate list. Selection considers environmental differences and a distance measure derived from the site data, with the aim of complementing sites already included in the monitoring network.

## Uses

Use this pipeline to prioritize candidate sites when expanding or rotating a monitoring network. Candidates may include historical sampling locations or proposed new sites.

The input list must identify two groups:

- **Current sites (`vini = 1`):** Sites already included in the monitoring network.
- **Candidate sites (`vini = 0`):** Sites available for additional sampling.

Together, these groups define the set of sites considered in the analysis. The pipeline extracts environmental values at their locations, calculates distance matrices, and selects additional sites through successive optimization steps.

The results include site-selection values, a map, and a curve showing how the remaining uncovered variability changes as sites are added. These outputs support decisions about which candidate sites to include and how many additional sites to sample.

## Pipeline limitations

- The analysis represents the supplied site list. Environmental conditions and locations absent from that list are not directly represented in the optimization.
- Results depend on the environmental variables, raster resolution, and candidate sites selected by the user.
- All sites need valid environmental data. Locations outside raster coverage or within cells containing missing values may prevent the analysis from completing.
- Computation time increases with the number of sites and optimization iterations. Start with a small run to assess performance.
- The current interface does not provide user-defined costs, accessibility constraints, or selection conditions.
- The selection CSV preserves the input-site order and does not provide coordinates or an explicit selection ranking.
- The uncovered-variability output is a measure derived from the optimization’s distance matrix. It should not be interpreted as a percentage of biodiversity represented.

## Before you start

Prepare a CSV containing one row per site and the following columns:

| Column | Description |
|---|---|
| `lon` | Longitude in decimal degrees, WGS84 (EPSG:4326). |
| `lat` | Latitude in decimal degrees, WGS84 (EPSG:4326). |
| `vini` | `1` for current monitoring sites; `0` for candidate sites. |

Use numeric values without missing coordinates or classifications. For the current implementation, keep the input file limited to these three columns.

Place the file in your BON in a Box `userdata` directory and enter its container path in **Sampling locations**, for example `/userdata/sampling_sites.csv`.

Choose environmental variables relevant to the monitoring objectives and ensure their coverage includes all supplied sites. Set the number of additional sites to a value no greater than the number of rows with `vini = 0`.

## Running the pipeline

### Pipeline inputs

- **Country, region, or bounding box:** Define the study extent and choose the coordinate reference system used to retrieve environmental data.

- **Spatial resolution:** Specify the environmental raster resolution in the units of the selected CRS: metres for a CRS measured in metres, or degrees for EPSG:4326. If left blank, the data loader attempts to use the native raster resolution, which requires compatible CRS units.

- **STAC collection items:** Provide the environmental variables using the format `collection|item`, such as `chelsa-clim|bio1` and `chelsa-clim|bio12`. These variables define the environmental differences between sites.

- **Sampling locations:** Provide the path to a CSV containing the `lon`, `lat`, and `vini` columns. Mark current sites with `1` and candidate sites with `0`.

- **Algorithm Iterations:** Enter the number of additional candidate sites to select. This must not exceed the number of candidate sites (`vini = 0`). For example, if the input contains 40 current sites and 60 candidate sites, select no more than 60 iterations. Start with fewer iterations to inspect the results before requesting a larger selection.

### Pipeline steps

#### 1. **Retrieve environmental data** 
Load the study-area polygon and selected environmental rasters.
#### 2. **Calculate site distances** 
Standardize the environmental rasters, extract values at the supplied sites, and calculate environmental and site-data distance matrices. Combine the matrices by multiplying their corresponding entries.
#### 3. **Select additional sites** 
Run the stepwise SURDES optimization using the current-site classifications and requested number of iterations.
#### 4. **Inspect the results** 
Review the selection values, map, and remaining uncovered-variability curve.

### Pipeline outputs

- **Site selection values:** A CSV containing the selection values calculated from the algorithm’s selection matrix. Values correspond to the input sites in their original row order. Interpret this file alongside the original sampling-locations CSV.

- **Uncovered variability:** A CSV containing the remaining uncovered-variability measure calculated at each optimization step.

- **Uncovered variability plot:** A plot showing how the remaining uncovered variability changes through the optimization steps. A flattening curve indicates that later additions provide smaller improvements under the chosen distance measure.

- **Selected-site map:** A map showing the supplied sites and their classifications in the algorithm output.

## References

- Medina, N. G., Lara, F., Mazimpaka, V., & Hortal, J. (2013). Designing bryophyte surveys for an optimal coverage of diversity gradients. *Biodiversity and Conservation*, 22(13–14), 3121–3139. https://doi.org/10.1007/s10531-013-0574-5

