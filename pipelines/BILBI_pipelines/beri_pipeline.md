_Authors: Jory Griffith, Nina Obiar_

Review status: In review

## Introduction

The CSIRO Bioclimatic Ecosystem Resilience Index (BERI) is a recognised component indicator within the Kunming-Montreal Global Biodiversity Framework (GBF) to directly asses Target 8, to minimize the impacts of climate change on biodiversity and build resilience. BERI measures the capacity of natural ecosystems to retain biodiversity in the face of climate change (Ferrier et al., 2020). The indicator is a function of ecosystem area, connectivity and integrity. The index is a global 30 arc-second product for the years 2000, 2005, 2010, 2015 and 2020 and is based on data for more than 400,000 species of plants, vertebrates, and invertebrates (Harwood et al., 2022). 

BERI assesses how well a landscape's configuration of natural habitat is able to accommodate climate-driven shifts in species distributions. For each grid-cell of natural habitat, the index evaluates the cell's functional connectivity to surrounding areas that are projected to support, under climate change, an assemblage of species similar to the one currently associated with that cell. Cells with well-connected habitat score highly, while isolated areas with no acccessible climatic analogue score poorly. The indicator can then be aggregated and reported by any desired spatial unit – e.g. an ecosystem type, a country, or the entire planet.


This pipeline calculates a weighted geometric mean of the BERI indicator over a region of interest.
The code to calculate the weighted mean was adapted from the "Calculating weighted geometric means of
CSIRO BILBI indicator" script on the
[CSIRO data access portal](https://doi.org/10.25919/4vvz-4j96)

### Uses
BERI can be used to assess Target 8 of the GBF. This indicator can be used to monitor and report past-to-present trends of the resilience of ecosystem condition and connectivity in the face of ongoing climate change. The index repeatedly recalculates the indicator using the best-available mapping of ecosystem condition or integrity observed at multiple points in time. 

It can also identify areas where biodiversity may be especially vulnerable to climate change, which areas are best to protect, and assess how proposed or implemented area-based actions are expected to retain species diversity thereby providing a stronger foundation for strategic prioritisation of such actions by member countries..

### Pipeline limitations

- BERI is a modeled layer, therefore there are greater uncertainties in areas with less data. Interpret the results with caution.

## Before you start

There are no data or API keys required for this analysis.

## Running the pipeline


### Pipeline inputs

BON in a Box contains a pipeline to calculate the BERI indicator for a given area of interest. The pipeline has the following user inputs:

- **Bounding Box and CRS:** the user must select a bounding box and coordinate reference system (CRS) to be used for the analysis. This can be done by using the chooser to either select a country and/or region, or enter or draw a custom bounding box. Then, an appropriate CRS can be selected from the corresponding drop-down menu.

- **Start date:** this input is optional. The user can select a start date for time series layers, in the format YYYY or YYYY-MM-DD. To perform the analysis on all available years, the user should leave this input blank. The layers start at 2020-01-01.

- **End date:** this input is optional. The user can select an end date for the time series layers, in the format YYYY or YYYY-MM-DD. To perform the analysis on all available years, the user should leave this input blank. The layers end at 2024-12-31.

- **Temporal resolution:** this input is optional. The user can select a temporal resolution for the query of STAC items by date, in the format ("P", time interval, and time unit, e.g. "P1Y" is yearly, "P1M" is monthly, and "P1D" is daily). If the temporal resolution is coarser than the temporal resolution of the time series, the layers will be aggregated with the aggregation method chosen below. The user should not put in a temporal resolution finer than that of the layer. The BERI dataset has a temporal resoltion of 5 years from 2000 until 2020 and then a layer for 2024. The user should leave this input blank if no start and end date was selected.

- **Spatial resolution:** the user can select the spatial resolution of the rasters. This must be in the same units as the coordinate reference system (meters for projected reference systems and degrees for reference systems in lat-long). To use the original spatial resolution of the layers, the user should leave this input blank. If the spatial resolution is left blank, the CRS selected must be EPSG:4326.

- **Resampling method:** the user must select a resampling method to be used when the analysis requires rescaling to a new spatial resolution and/or reprojecting of the raster layers.
For more information on which resampling method (i.e., near, bilinear) to use please visit [gdalwarp](https://gdal.org/en/latest/programs/gdalwarp.html). This input will be ignored if there is no need for resampling.

- **Aggregation method:** the user must select a method to aggregate items when layers are combined over time, e.g. if a courser temporal resolution is chosen. This input will be ignored if there is no need for aggregation (the temporal resolution of the
original layers is selected).

### Pipeline steps

#### **1. Getting the polygon of the area of interest**

This step returns the polygon for the country/region/area of interest. If a country/region was selected, it pulls the country/region polygon using the [GeoBoundaries API](https://www.geoboundaries.org/), and outputs as a geopackage, projected in the crs of interest. If the user inputs a custom bounding box, it will return a polygon made from that bounding box.

#### **2. Loading data from the GEO BON STAC catalog**

This step first extracts the CSIRO Bioclimatic Ecosystem Resilience Index (BERI) layers, then the CSIRO denominator layers, from collections on the GEO BON Spatio Temporal Asset Catalog. The layers are in EPSG:4326 and 10x10 km resolution but the user can specify other coordinate references systems and spatial resolutions. The CSIRO denominator layers are use to calculate the weighted geometric mean of the CSIRO BERI layers.

#### **3. Calculating the weighted arithmetic mean for the BERI layers**

This step calculates the weighted arithmetic mean for the BERI layers to calculate the summary statistics over the area of interest.

### Pipeline outputs

- **Raster layers of indicator for each year:** raster files of the BERI layers in geotiff format.

- **BERI summary:** yearly weighted geometric mean of the BERI in the area of interest. The value ranges from 0 to 1, and represents the proportion of connected habitat expected to remain under climate change compared to what would exist without human modification or climate change.

- **Time series plot:** plot of the geometric mean of the BERI over time in the area of interest.

- **Country:** the country of interest, if any.

- **Region:** the region of interest, if any.

## Example

Example output available soon.

## Troubleshooting
Problems with the pipeline can be directed to @info.boninabox.org

## References
Ferrier, Simon; Harwood, Thomas D.; Ware, Chris; Hoskins, Andrew J (2020): A globally applicable indicator of the capacity of terrestrial ecosystems to retain biological diversity under climate change: The bioclimatic ecosystem resilience index. Ecological Indicators. doi: https://doi.org/10.1016/j.ecolind.2020.106554.

Harwood, Tom; Ware, Chris; Hoskins, Andrew; Ferrier, Simon; Bush, Alex; Golebiewski, Maciej; Hill, Samantha; Ota, Noboru; Perry, Justin; Purvis, Andy; & Williams, Kristen (2022): BERI v2: Bioclimatic Ecosystem Resilience Index: 30s global time series. v2. CSIRO. Data Collection. doi: https://doi.org/10.25919/4vvz-4j96