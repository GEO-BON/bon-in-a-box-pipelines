_Authors: Jory Griffith, Laetitia Tremblay_

Review status: In development

## Introduction
Phenology is one of the species trait EBVs. It describes presence, absence, abundance or duration of seasonal activities of organisms. This pipeline uses the openEO python package to pull phenology layers from the copernicus data space ecosystem phenology layer. The raster has values for the Plant Phenology Index (PPI), which is a vegetation index that helps estimate vegetation health and photosyntehtic activity throughout the growing season. It is more directly related to plant phenology compared to other vegetation indices like NDVI, and does not saturate in high biomass conditions. It is computed with near infrared reflectance, which is strongly reflected by healthy vegetation. You can read more about the phenology layers [here](https://land.copernicus.eu/en/dataset-catalog). The script pulls the yearly phenology layers using openEO and resamples them to the spatial resolution of choice, calculates summary statistics over a country or region of interest, and subtracts the rasters to look at change over time.

## Uses
This pipeline can be used to look at the Phenology EBV. It can also serve as inputs for subsequent pipelines, such as species distribution models.

## Pipeline limitations

- Phenology layers are only available for countries in Europe.
- The pipeline uses a very fine resolution, so it takes a long time to run on for large areas.

## Before you start
The pipeline requires an API key for the Copernicus Data Space Ecosystem. To acquire an API key, visit the CDSE [website](https://dataspace.copernicus.eu/analyse/openeo).

## Running the pipeline

### Pipeline inputs

- **Bounding Box and CRS:** the user must select a bounding box and coordinate reference system (CRS) to be used for the analysis. This can be done by using the chooser to either select a country and/or region, or type in/draw a custom bounding box. Then, an appropriate CRS can be selected from the corresponding drop-down menu.

- **Season of interest:** season for which to run the phenology analysis. Can be either Season1 or Season2, where the former is the first growing season (spring and early summer) and the latter is the second growing season (late summer and fall).

- **Bands:** raster bands of interest for the calculations.

- **Spatial resolution:** the user can select the spatial resolution of the rasters. This must be in the same units as the coordinate reference system (meters for projected reference systems and degrees for reference systems in lat-long). To use the original spatial resolution of the layers (10m x 10m), the user should leave this input blank. In that case, the CRS selected must be EPSG:4326.

- **Start year:** this input is optional. The user can select a start date for the phenology time series, in the format YYYY or YYYY-MM-DD. To perform the analysis on all available dates, the user should leave this input blank.start year for the phenology time series.

- **End year:** this input is optional. The user can select an end date for the phenology time series, in the format YYYY or YYYY-MM-DD. To perform the analysis on all available dates, the user should leave this input blank.

- **Aggregate function:** the user can choose which function to use to spatially aggregate the phenology data. Can be mean, maximum (max), or mininum (min). The pipeline will return a layer with the summarised values over the time period of interest for each pixel. This input will be ignored if there is no need for aggregation.

### Pipeline steps

#### **1. Getting the polygon of the area of interest**
This step returns the polygon for the country/region/area of interest. If a country/region was selected, it pulls the country/region polygon using the [GeoBoundaries API](https://www.geoboundaries.org/), and outputs as a geopackage, projected in the crs of interest. If the user inputs a custom bounding box, it will return a polygon made from that bounding box.

#### **2. Summarising the phenology**
This step summarises the yearly phenology data for the country of interest using the copernicus data space ecosystem phenology layer. The openEO python client is used to send a job to openEO. The raster has values for the Plant Phenology Index (PPI), which is a vegetation index that helps estimate vegetation health and photosyntehtic activity throughout the growing season. It is more directly related to plant phenology compared to other vegetation indices like NDVI, and does not saturate in high biomass conditions. It is computed with near infrared reflectance, which is strongly reflected by healthy vegetation.

#### **3. Calculating change in phenology**
This step calculates the difference in the layers of the phenology raster layers from the start year to the end year, or for all available layers if no date is selected, to show the spatial distribution of changes in phenology.

### Pipeline outputs

- **Country:** country of interest, if selected.

- **Region:** region of interest, if selected.

- **Phenology rasters:** rasters of phenology layers, with one raster per year in the input time range. Will either be the raw raster layers or resampled to the spatial resolution input by the user.

- **Change in phenology metrics:** raster plot of change in phenology from the start year to the end year. The end year is subtracted from the start year, so larger values indicate a greater decrease in the given value over time.

- **Plot of phenology change:** plot of the summarised phenology values over time for the bands of interest.

- **Zonal statistics:** summarised values over the country/region of interest based on the aggregate function input by the user, for each year for each band of interest.

## Example
**Sample run:** See an example Phenology run here in the [run ui](https://pipelines-results.geobon.org/pipeline-form/Phenology%3Ephenology_EO/f08ed95a9538d87c7303027390889fba) and [viewer](https://pipelines-results.geobon.org/viewer/Phenology%3Ephenology_EO%3Ef08ed95a9538d87c7303027390889fba).

## Troubleshooting

## References
Copernicus Land Monitoring Service. (2024). High Resolution Vegetation Phenology and Productivity: Plant Phenology Index (raster 10 m), version 1 revision 1 [Dataset]. European Union. https://land.copernicus.eu/en/access-data/copernicus-services-catalogue/high-resolution-vegetation-phenology-and-productivity-1


