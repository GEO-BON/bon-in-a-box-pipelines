# Biodiversity Intactness Index
### Author(s): Jory Griffith
#### Reviewed by: In review

## Introduction
The Biodiversity Intactness Index (BII) is a metric designed to assess the degree to which ecosystems are intact and functioning relative to their natural state. It measures the abundance and diversity of species in a given area compared to what would be expected in an undisturbed ecosystem. The BII accounts for various factors, including habitat loss, fragmentation, and degradation, providing a comprehensive view of biodiversity health. A higher BII value indicates a more intact ecosystem with greater species diversity and abundance, while a lower value suggests significant ecological disruption. The biodiversity intactness index is a complimentary indicator in the GBF. The BII was created by the Natural History Museum and uses their PREDICTS database, which aggregates data from studies comparing terrestrial biodiversity at sites experiencing varying levels of human pressure. The database is used to establish a reference state using the biodiversity patterns in habitats with minimal disturbance levels. Then, it assigns sensitivity scores to each species based on their vulnerability to human pressure. Intactness is calculated by comparing the observed species abundance in a given area to what is expected under reference conditions with low human impact. It currently contains over 3 million records from more than 26,000 sites across 94 countries, representing a diverse array of over 45,000 plant, invertebrate, and vertebrate species.

## 'Use Case'/Context
The Biodiversity Intactness Index is a compimentary indicator in the GBF. This pipeline can be used to calculate summary statistics and plot a time series of the 10km resolution BII layer for a given country or region. The BII is expressed as a percentage, with higher percentages being more intact.

## Pipeline limitations
The pipeline does not model the Biodiversity Intactness Index from the data, it calculates summary statistics over the already calculated global layer at 10x10km resolution. Therefore, you cannot customize the model or input custom data. Additionally, because BII is a modelled data layer, the values may be less accurate in areas where there is a lack of data. To learn more about the PREDICTS database, visit the [page on the Natural History Museum website](https://www.nhm.ac.uk/our-science/research/projects/predicts/science.html).

## Before you start
There are no data or API keys required for this analysis. To view the global layer, go to our [STAC catalog](https://stac.geobon.org/viewer/bii_nhm/bii_nhm_10km_2020).

## Running the pipeline

### Pipeline inputs
The Natural History Museum has created raster layers of BII since the year 2000. BON in a Box has a pipeline to calculate summary statistics and plot a time series from these layers in a country, region, or custom study area of interest. The pipeline has the following inputs:

- **Country:** country of interest.

- **State/Province:** region of interest.

- **Summary statistic:** the user can choose the summary statistic for BII (options: mean, median, mode) that will be calculated for the country or region of interest.

- **Start year for BII raster comparison:** reference BII year for raster plotting.

- **End year for BII comparison:** BII layer to compare to the start year.

- **Coordinate reference system:** the coordinate reference system of choice. Search for a CRS of interest [here](https://epsg.io/). This needs to be a projected coordinate reference system (in meters).

- **Spatial resolution:** the spatial resolution of the rasters (in meters).

### Pipeline steps

#### **1. Getting the country bounding box**
This step retrieves the bounding box for the country/region of interest using the `Get country bounding box` pipeline.

#### **2. Loading data from the GEO BON STAC catalog**
This step extracts geospatial data from various collections on the GEO BON Spatio Temporal Asset Catalog.

#### **3. Calculating zonal statistics**
This step calculates the zonal statistics for the raster layers obtained from the GEO BON STAC catalog over the bounding box from step 1, using the R package exactextractr.

#### **4. Calculating the BII change**
This step generates a raster of the change in the BII between the two chosen time points. The BII uses the PREDICTS database to establish a reference state using the biodiversity patterns in habitats with minimal disturbance levels. Then, it assigns sensitivity scores to each species based on their vulnerability to human pressure. Intactness is calculated by comparing the observed species abundance in a given area to what is expected under reference conditions with low human impact.

### Pipeline outputs

- **Rasters:** the user can view all of the raster layers for each year that were used to generate the summary statistics.

- **Summary statistic:** a table of the summary statistic values of BII over years.

- **Change in BII:** a raster plot of the change in BII between the two chosen years. Higher numbers indicate greater BII loss.

- **Country:** the region of interest.

- **Region:** the country of interest.

## Example
**Sample run:** See an example BII run here in the [run ui](https://pipelines-results.geobon.org/pipeline-form/BII%3EBII/5411ef9f7f4b1444a865a05acee4e136) and [viewer](https://pipelines-results.geobon.org/viewer/BII%3EBII%3E5411ef9f7f4b1444a865a05acee4e136).

## Troubleshooting
- The spatial resolution of the BII layers in 10 km (10,000 m). Choosing a spatial resolution lower than that may cause problems.

## References
Adriana De Palma; Sara Contu; Gareth E Thomas; Connor Duffin; Sabine Nix; Andy Purvis (2024). The Biodiversity Intactness Index developed by The Natural History Museum, London, v2.1.1 (Open Access, Limited Release) [Data set]. Natural History Museum. https://doi.org/10.5519/k33reyb6

Newbold, T., Hudson, L. N., Arnell, A. P., Contu, S., De Palma, A., Ferrier, S., Hill, S. L. L., Hoskins, A. J., Lysenko, I., Phillips, H. R. P., Burton, V. J., Chng, C. W. T., Emerson, S., Gao, D., Pask-Hale, G., Hutton, J., Jung, M., Sanchez-Ortiz, K., Simmons, B. I., … Purvis, A. (2016). Has land use pushed terrestrial biodiversity beyond the planetary boundary? A global assessment. Science, 353(6296), 288–291. https://doi.org/10.1126/science.aaf2201



