_Author(s): Francis van Oordt

Reviewed by: Reviewer names


## Introduction
Site optimization is challenge in biodiversity monitoring. Often times ecological monitoring selects sampling locations based on multiple reason. Reasons vary from sampling design, budget and accesibility constraints, and rotational site selection, among others. Such variation may produce a set of current or well-known of locations, and historical or demand site (site which have not been samples in a many years). Given that monitoring projects could increase or rotate new sampling location, decision of how to define this sites can be informed by environmental variability, that may help understand better biodiversity patterns.

## Uses
The pipeline selects a set of locations from a pool of demand sites (historical sites or not recently sampled sites) using a stepwise procedure through a pmedians algorithm. The algorith aims to select sites that cover greatest environmental and spatial distance. Selected sites will contribute to cover the remaining environmental variability based on the universal variability (universe defined by well-know and historical sites together). but the historical sites alone, and select among the Demand sites. The user must provide a dataframe with well- know survey sites (current) and demand sites (or historical sites), a will select sites only from the demand site pool.

## Pipeline limitations
Optimization algorithm is based on only a subset of points (demand) from a universe (well-know and demand) that defines the environmental and spatial variability.
The p-median algortihm is slow with large matrices (more than ~200 sites) depending on computing power.
Selection of environmental variables is key to defining universal environmental variability, therefore results may vary significantly based on the ßected envionrmental variables.
Boundary is limited to spatial polygons defined by the avalilabe country bounding box polygons within Bon-in-a-Box.

## Before you start
No API keys are needed to run this pipeline.

You need to run the pipeline with a custom set of point locations for your study area, input your file (.csv only) pth starting from the user data folder into the "Sampling locations" input box.

The point locations file should be a simple a dataframe of points with the correct column labels: "lat"", "lon"", and "vini"" (this are the initial values for algorithm, which can only be 1 or 0, for currently sampled sites and historical sites, respectively).



## Running the pipeline

### Pipeline inputs
BON in a Box contains a pipeline to optimize the selection of new sampling locations from a historical set of location that complement the spatial and environmental variability of currently sampled sites. The pipeline has the following user inputs:

- **Country, region, or bounding box:** Use the chooser to select a country/ region or create a custom bounding box (region selections will be ignored for EEZs since they are national).

- **Polygon type:** Type of polygon to load. Country or region polygons, World database of Protected Areas (WDPA), or Exclusive Economic Zones (EEZs).

- **STAC collection items:** Vector of strings, collection name followed by '|' followed by item id

- **Sampling locations:** Sampling locations/site in lat lon format, including a "vini" column (defining well-known sites as "1" and demand/historic sites as "0", which will be selected for the sampling optimization)

- **Aggregation factor (resolution):** Factor reduction for raster pixel resolution (usually from 1km raw)

- **Algorithm Iterations:** Number of iterations to run (equivalent to sites to be selected from the demand sites pool. NOTE: it has to be equal or less that the "demand sites" number)

- **Spatial resolution:** Integer, spatial resolution of the rasters in the same units as the coordinate reference system (meters for projected reference systems and degrees for reference systems in lat long). This input may be blank when using ESPG:4326.

#### **1. Retrieving the data**
This step retrieves data from this place using this API.

#### **2. Cleaning the data**
This step uses this package to clean the data for this reason.

#### **3. Analyzing the data**
This step analyzes this data to produce this indicator. This is how it works.

Etc.

### Pipeline outputs

- **Selection of demand points:** resulting points selected by the algorithm that best complement the currently surveyed points (based on the spatial and environmental variance of the universe of points).

- **Plot for uncovered variance:** Visualization of the variance covered by each additional new point selected from the historical set. 

- **Map for selected points:** Visual representation in space of the currently sampled, historical, and selected points. 

## Example


## Troubleshooting
**Common errors:**

- `Error 1`: *description*
- `Error 2`: *description*


## References
- Medina, N. G., Lara, F., Mazimpaka, V., & Hortal, J. (2013). Designing bryophyte surveys for an optimal coverage of diversity gradients. Biodiversity and Conservation, 22(13–14), 3121–3139.
- https://doi.org/10.1007/s10531-013-0574-5


