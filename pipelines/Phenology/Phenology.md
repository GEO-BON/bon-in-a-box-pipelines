# Phenology
### Author(s): Jory Griffith, Laetitia Tremblay
#### Reviewed by: In review

## Introduction
Phenology is one of the species trait EBVs. It describes presence, absence, abundance or duration of seasonal activities of organisms. This pipeline uses the openEO python package to pull phenology layers from the copernicus data space ecosystem phenology layer. The raster has values for the Plant Phenology Index (PPI), which is a vegetation index that helps estimate vegetation health and photosyntehtic activity throughout the growing season. It is more directly related to plant phenology compared to other vegetation indices like NDVI, and does not saturate in high biomass conditions. It is computed with near infrared reflectance, which is strongly reflected by healthy vegetation. You can read more about the phenology layers [here](https://land.copernicus.eu/en/dataset-catalog). The script pulls the yearly phenology layers using openEO and resamples them to the spatial resolution of choice, calculates summary statistics over a country or region of interest, and subtracts the rasters to look at change over time.

## 'Use Case'/Context
This pipeline can be used to look at the Phenology EBV. It can also serve as inputs for subsequent pipelines, such as species distribution models.

## Pipeline limitations

- Phenology layers are only available for countries in Europe.
- The pipeline uses a very fine resolution, so it takes a long time to run on for large areas.
- The pipeline outputs layers only in EPSG:4346.

## Before you start
The pipeline requires an API key for the Copernicus Data Space Ecosystem. To acquire an API key, visit the CDSE [website](https://dataspace.copernicus.eu/analyse/openeo).

## Running the pipeline

### Pipeline inputs

- **Season of interest:** season for which to run the phenology analysis. Can be either Season1 or Season2, where the former is the first growing season (spring and early summer) and the latter is the second growing season (late summer and fall).

- **Bands:** raster bands of interest for the calculations.

- **Spatial resolution:** spatial resolution (in meters) of the raster, for plotting. Leave blank to extract layers in the original spatial resolution (10m x 10m).

- **Start year:** start year for the phenology time series.

- **End year:** end year for the phenology time series.

- **Aggregate function:** the user can choose which function to use to spatially aggregate the phenology data. Can be mean, maximum (max), or mininum (min). The pipeline will return a layer with the summarised values over the time period of interest for each pixel.

- **ISO3 country code:** the user can input the [ISO3 country code](https://en.wikipedia.org/wiki/ISO_3166-1_alpha-3) of the country of interest and the pipeline will pull the polygon and protected areas for this country.

- **State/Province:** the user can specify a state/province within the country of interest and the pipeline will pull the polygon and protected areas for this region. This is input as the full name of the state.

#### **1. Retrieving the bounding box**
This step retrieves the bounding box for the country/region of interest in EPSG:4326.

#### **2. Summarising the phenology**
This step summarises the yearly phenology data for the country of interest using the copernicus data space ecosystem phenology layer. The openEO python client is used to send a job to openEO. The raster has values for the Plant Phenology Index (PPI), which is a vegetation index that helps estimate vegetation health and photosyntehtic activity throughout the growing season. It is more directly related to plant phenology compared to other vegetation indices like NDVI, and does not saturate in high biomass conditions. It is computed with near infrared reflectance, which is strongly reflected by healthy vegetation.

#### **3. Calculating change in phenology**
This step calculates the difference in the layers of the phenology raster layers from the start year to the end year to show the spatial distribution of changes in phenology.

### Pipeline outputs

- **Zonal statistics:** summarised values over the country/region of interest based on the aggregate function input by the user, for each year for each band of interest.

- **Phenology rasters:** rasters of phenology layers, with one raster per year in the input time range. Will either be the raw raster layers or resampled to the spatial resolution input by the user.

- **Change in phenology metrics:** raster plot of change in phenology from the start year to the end year. The end year is subtracted from the start year, so larger values indicate a greater decrease in the given value over time.

- **Plot of phenology change:** plot of the summarised phenology values over time for the bands of interest.

- **Country:** country of interest.

- **Region:** region of interest.

## Example
Example output available soon.

## Troubleshooting

## References
Copernicus Land Monitoring Service. (2024). High Resolution Vegetation Phenology and Productivity: Plant Phenology Index (raster 10 m), version 1 revision 1 [Dataset]. European Union. https://land.copernicus.eu/en/access-data/copernicus-services-catalogue/high-resolution-vegetation-phenology-and-productivity-1


