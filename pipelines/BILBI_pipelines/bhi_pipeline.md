_Authors: Jory Griffith_

Review status: In review

## Introduction

The CSIRO Biodiversity Habitat Index (BHI v2) is a global 30 arc-second product
for 2000,2005,2010,2015 and 2020. BHI estimates the level of species diversity
expected to be retained within any given spatial reporting unit (e.g., a
country, a broad ecosystem type, or the entire planet) as a function of the
unit’s area, connectivity and integrity of natural ecosystems across it.
Results for the indicator can either be expressed as 1) the ‘effective
proportion of habitat’ remaining within the unit – adjusting for the effects
of the condition and functional connectivity of habitat, and of spatial
variation in the species composition of ecological communities (beta
diversity); or 2) the effective proportion of habitat that can be translated,
through standard species-area analysis, into a prediction of the proportion of
species expected to persist (i.e. avoid extinction) over the long term.

## Uses

The BHI is used to monitor and report past-to-present trends in the expected
persistence of species diversity by repeatedly recalculating the indicator
using best-available mapping of ecosystem condition or integrity observed at
multiple points in time, e.g., for different years. A wide variety of data
sources can be used for this purpose, spanning spatial scales from global to
subnational, and including data assembled by countries for deriving ecosystem
condition accounts under the UN SEEA Ecosystem Accounting framework. The BHI
can also serve as a leading indicator for assessing the contribution that
proposed or implemented area-based actions are expected to make towards
enhancing the present capacity of ecosystems to retain species diversity,
thereby providing a foundation for strategic prioritisation of such actions by
countries.

### Pipeline limitations
- BHI is a modeled layer, therefore there are greater uncertainties in areas with less data. Interpret the results with caution.

## Before you start
There are no data or API keys required for this analysis.

## Running the pipeline


### Pipeline inputs

BON in a Box contains a pipeline to calculate the BHI indicator for a given area of interest. The pipeline has the following user inputs:

- **Bounding Box and CRS:** the user must select a bounding box and coordinate reference system (CRS) to be used for the analysis. This can be done by using the chooser to either select a country and/or region, or type in/draw a custom bounding box. Then, an appropriate CRS can be selected from the corresponding drop-down menu.

- **Start date:** this input is optional. The user can select a start date for time series layers, in the format YYYY or YYYY-MM-DD. To perform the analysis on all available dates, the user should leave this input blank.

- **End date:** this input is optional. The user can select an end date for the time series layers, in the format YYYY or YYYY-MM-DD. To perform the analysis on all available dates, the user should leave this input blank.

- **Temporal resolution:** this input is optional. The user can select a temporal resolution for the query of STAC items by date, in the format ("P", time interval, and time unit, e.g. "P1Y" is yearly, "P1M" is monthly, and "P1D" is daily). If the temporal resolution is coarser than the temporal resolution of the time series, the layers will be aggregated with the aggregation method chosen below. The user should leave this input blank if no start and end date was selected.

- **Spatial resolution:** the user can select the spatial resolution of the rasters. This must be in the same units as the coordinate reference system (meters for projected reference systems and degrees for reference systems in lat-long). To use the original spatial resolution of the layers, the user should leave this input blank. In that case, the CRS selected must be EPSG:4326.

- **Resampling method:** the user must select a resampling method to be used when the analysis requires rescaling and/or reprojecting of the raster layers.
See [gdalwarp](https://gdal.org/en/latest/programs/gdalwarp.html) for a description. This input will be ignored if there is no need for resampling.

- **Aggregation method:** the user must select a method to aggregate items when layers are combined over time. This input will be ignored if there is no need for aggregation.

### Pipeline steps

#### **1. Getting the polygon of the area of interest**

This step returns the polygon for the country/region/area of interest. If a country/region was selected, it pulls the country/region polygon using the [GeoBoundaries API](https://www.geoboundaries.org/), and outputs as a geopackage, projected in the crs of interest. If the user inputs a custom bounding box, it will return a polygon made from that bounding box.

#### **2. Loading data from the GEO BON STAC catalog**

This step first extracts the CSIRO Biodiversity Habitat Index (BHI) layers, then the CSIRO denominator layers, from collections on the GEO BON Spatio Temporal Asset Catalog. The layers are in EPSG:4326 and 10x10 km resolution but the user can specify other coordinate references systems and spatial resolutions. The CSIRO denominator layers are use to calculate the weighted geometric mean of the CSIRO BHI layers.

#### **3. Calculating the weighted arithmetic mean for the BHI layers**

This step calculates the weighted arithmetic mean for the BHI layers to calculate the summary statistics over the area of interest.

### Pipeline outputs

- **Raster layers of indicator for each year:** raster files of the BHI layers in geotiff format.

- **BHI summary:** yearly weighted geometric mean of the BHI in the area of interest. The value ranges from 0 to 1, where a higher value indicates that a large proportion of the habitat remains in good condition and is well-connected, leading to a high expectation of species persistence. A lower value indicates that a significant proportion of the original habitat has been lost, degraded, or fragmented, which puts biodiversity at risk.

- **Time series plot:** plot of the geometric mean of the BHI over time in the area of interest.

- **Country:** the country of interest, if any.

- **Region:** the region of interest, if any.

## Example
Example output available soon.

## Troubleshooting

## References

Harwood, Tom; Ware, Chris; Hoskins, Andrew; Ferrier, Simon; Bush, Alex; Golebiewski, Maciej; Hill, Samantha; Ota, Noboru; Perry, Justin; Purvis, Andy; & Williams, Kristen (2022): BHI v2: Biodiversity Habitat Index: 30s global time series. v1. CSIRO. Data Collection. doi: 10.25919/tt2t-h452