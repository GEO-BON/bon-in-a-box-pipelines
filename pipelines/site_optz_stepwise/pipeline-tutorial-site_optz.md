_Authors: Francis van Oordt, Samara Manzin_

## Introduction

Biodiversity monitoring programmes may need to expand their sampling network or revisit sites that are no longer regularly monitored. Choosing additional sites can help improve coverage of environmental conditions and geographic areas that are poorly represented by the current network.

This pipeline uses a stepwise p-median optimization procedure implemented in the SURDES package to select additional sites from a user-provided candidate list. Selection considers environmental differences and geodesic distances between site coordinates in metres, with the aim of complementing sites already included in the monitoring network.

## Uses

Use this pipeline to prioritize demand points when expanding or rotating a monitoring network. Demand points may include historical sampling locations or proposed new sites.

The input list must identify two groups:

- **Current sites (`vini = 1`):** Sites already included in the monitoring network.
- **Demand points (`vini = 0`):** Sites available for additional sampling.

Together, these groups define the set of sites considered in the analysis. The pipeline extracts environmental values at their locations, calculates distance matrices, and selects additional sites through successive optimization steps.

The results include site-selection values, a map, and a curve showing how the remaining uncovered variability changes as sites are added. These outputs support decisions about which demand points to include and how many additional sites to sample.

## Pipeline limitations

- The analysis represents the supplied site list. Environmental conditions and locations absent from that list are not directly represented in the optimization.
- All sites need valid environmental data. Locations outside raster coverage or within cells containing missing values may prevent the analysis from completing.
- Computation time increases with the number of sites and optimization iterations. Start with a small run to assess performance.
- The current interface does not provide user-defined costs, accessibility constraints, or selection conditions.
- The uncovered-variability output is a measure derived from the optimization’s distance matrix. It should not be interpreted as a percentage of biodiversity represented.

## Before you start

Prepare a CSV containing one row per site and the following columns:

- **lon:** Longitude in decimal degrees, WGS84 (EPSG:4326).

- **lat:** Latitude in decimal degrees, WGS84 (EPSG:4326).

- **vini:** The initial site-selection indicator used by the optimization. Use 1 for current monitoring sites and 0 for demand points available for additional sampling.

Use numeric values without missing coordinates or classifications. Include at least one current site and one demand point. Extra columns may contain site identifiers or other attributes; they do not enter the distance calculations.

Input coordinates must always be WGS84 longitude and latitude, regardless of the CRS selected in the location chooser. Sites are reprojected internally for extracting environmental data; geographic distances are calculated directly from WGS84 coordinates.

Place the file in your BON in a Box `userdata` directory and enter its container path in **Sampling locations**, for example `/userdata/sampling_sites.csv`.

The environmental variables, raster resolution, and supplied demand points determine the differences considered by the optimization. Choose variables relevant to the monitoring objectives and ensure their coverage includes all supplied sites. Set the number of additional sites to a value no greater than the number of rows with `vini = 0`.

## Running the pipeline

### Pipeline inputs

- **Country, region, or bounding box:** Define the study extent and choose the coordinate reference system used to retrieve environmental data.

- **Spatial resolution:** Environmental raster resolution in the selected CRS units: metres for a CRS measured in metres, degrees for EPSG:4326. If blank, the loader attempts native resolution, requiring compatible CRS units. This does not change the required WGS84 input coordinates or the geodesic distance method.

- **STAC collection items:** Provide the environmental variables using the format `collection|item`, such as `chelsa-clim|bio1` and `chelsa-clim|bio12`. These variables define the environmental differences between sites.

- **Sampling locations:** Path to one CSV with lon and lat in WGS84 decimal degrees (EPSG:4326), and vini: 1 for current sites, 0 for demand points. Input coordinates always use WGS84, independently of the selected processing CRS.

- **Algorithm Iterations:** Positive integer number of demand points to add. Must not exceed the number of rows with vini = 0. For example, 40 current sites and 60 demand points allow at most 60 additions. More iterations take longer.

### Pipeline steps

#### 1. **Retrieve environmental data** 
Load the study-area polygon and selected environmental rasters.
#### 2. **Calculate site distances** 
Standardize the environmental rasters and calculate Euclidean distances between the values extracted at sites. Separately, calculate ellipsoidal geodesic distances in metres from the WGS84 coordinates. Multiply corresponding entries to create the joint distance matrix. Site classification (vini) is used by the optimizer, not in either distance calculation.

With this multiplication, a zero distance in either component gives a zero joint distance. Changing the raster CRS or resolution can affect environmental values; it does not change the geographic distance method.
#### 3. **Select additional sites** 
Scale the joint distance matrix by its maximum value so all entries are between 0 and 1, preserving their relative differences. This accommodates the distance cap used internally by SURDES. Run the stepwise optimization using the current-site classifications and requested number of iterations. If all demand points are requested, the sole remaining point is added directly at the final step to avoid a single-candidate limitation in SURDES.
#### 4. **Inspect the results** 
Review the selection values, map, and remaining uncovered-variability curve.

### Pipeline outputs

- **Selection of demand points:** CSV of newly selected demand points in selection order, including lon, lat, vini, site_row (original CSV row, starting at 1), selected, selection_order, and status. Current sites are excluded.

- **Uncovered variability:** CSV with iteration and uncovered_variability, calculated as the sum of SURDES p-median scores at each iteration. This diagnostic is not a percentage of biodiversity represented and is not guaranteed to decrease monotonically.

- **Uncovered variability plot:** PNG showing the sum of SURDES p-median scores at each iteration. Inspect alongside the selected sites; this diagnostic is not a percentage of biodiversity represented.

- **Map for selected points:** PNG showing current sites, unselected demand points, and selected demand points in different colours.

- **Sampling sites GeoPackage:** GeoPackage containing all input sites in WGS84 with vini, site_row, selected, selection_order, and status (Current, Demand, or Selected). Use status for viewer styling; automatic colours depend on the viewer.

## References

- Medina, N. G., Lara, F., Mazimpaka, V., & Hortal, J. (2013). Designing bryophyte surveys for an optimal coverage of diversity gradients. *Biodiversity and Conservation*, 22(13–14), 3121–3139. [Read the paper](https://doi.org/10.1007/s10531-013-0574-5)

