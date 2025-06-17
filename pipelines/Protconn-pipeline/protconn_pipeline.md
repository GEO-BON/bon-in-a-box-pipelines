# Protected Connected Index
### Author(s): Jory Griffith
#### Reviewed by:

## Introduction

The Protected Connected Index (ProtConn) is a component indicator in the Global Biodiversity Framework (GBF). ProtConn measures the percent of a given country or region that is conserved and managed through well-connected protected areas. This is an important indicator for assessing progress towards Goal A and Target 3 of the Kunming-Montreal Global Biodiversity Framework, which aim to have 30% of land area protected by a network of well-connected protected areas by 2030.

### Uses

ProtConn can be used to assess current progress towards Goal A and Target 3 of the the GBF. The pipeline can also be used to compare the connectedness of different proposed protected areas, assisting with planning and design.

### Pipeline limitations

- On larger datasets, the pipeline is slow and uses a lot of memory
- Currently, the pipeline does not take into account landscape resistance (ie. whether areas between protected areas are easily traversed by species)

## Before you start

To use this pipeline, you’ll need a [Protected Planet API key](https://api.protectedplanet.net/request) to access data on the World Database of Protected Areas. If you would like to run the pipeline with custom protected area data, ensure your data is in GeoPackage format and use the `ProtConn Analysis with custom PAs` pipeline.

## Running the pipeline



### Pipeline inputs

BON in a Box contains a pipeline to calculate ProtConn for a given country or region of interest. The pipeline has the following user inputs:

- **ISO3 country code:** the user can input the [ISO3 country code](https://en.wikipedia.org/wiki/ISO_3166-1_alpha-3) of the country of interest and the pipeline will pull the polygon and protected areas for this country.

- **State/Province:** the user can specify a state/province within the country of interest and the pipeline will pull the polygon and protected areas for this region. This is input as the full name of the state.

**Polygon of study area:** there is also an option to add a custom study area file, which will override the polygon from the specified country or region of interest.

- **Polygon of protected areas:** this input should only be used if the user wants to use custom protected area data, for example if they want to calculate ProtConn for proposed protected areas or protected areas that are not yet in WDPA. If you use the `ProtConn Analysis with WDPA` pipeline, this input is optional and any file added will be combined with WDPA data of the country of interest. If you use the `ProtConn Analysis with custom PAs` pipeline, this input is mandatory and the pipeline will analyze only user-input protected area polygons.

- **Coordinate Reference System:** the coordinate reference system of choice. Search for a CRS of interest [here](https://epsg.io/). This needs to be a projected coordinate reference system for ProtConn calculations.

- **Date Column Name:** the user must indicate the name of the column in the custom protected area data file that specifies when the protected area was created (leave blank if only using WDPA data).

- **Distance analysis threshold:** the user can specify one or more dispersal distances depending on which species they are interested in. Common dispersal distances are 1,000 meters (1km), 10,000 m (10km) and 100,000 m (100 km) The dispersal distance is the median of the negative exponential dispersal kernel, meaning that at that distance there is a dispersal probability of 0.5. Note that larger dispersal distances will be more computationally intensive.
  ![](images/Image17.png)

- **Type of distance matrix:** the user can specify whether the distances between protected areas should be measured using the centroid (geometric center) of the protected area or the closest edge.

  ![](images/Image18.PNG)
  ![](images/Image19.PNG)

- **Year for cutoff:** the user can specify a year for the analysis. The analysis will only calculate values for protected areas that were established before this cutoff year.

- **Start year:** the start year of the time series of ProtConn values. The time series will calculate ProtConn for the protected areas established on or before the chosen year, and will count up to the cutoff year by the specified interval.

- **Year interval:** the year interval for the time series of ProtConn values. (eg. an input of 10 will calculate ProtConn values every 10 years).

- **PA legal status types to include:** the user can choose legal status types of WDPA data to include in the analysis. The protected areas can have a legal status of `Designated`, `Inscribed`, or `Established`.
 - Designated means that it is officially established under national or international law/policy.
 - Inscribed means that it is inscribed in an international list (e.g. World Heritage). This can overlap with designated.
 - Established means that it is protected and managed, but possibly lacks formal legal designation.

- **Include UNESCO Biosphere reserves:** the user can specify whether they want to include UNESCO Man and the Biosphere reserves in the analysis or not. These serve as learning sites for sustainable development and combine biodiversity conservation with the sustainable use of natural resources and sustainable development. They may not be legally protected and may not be fully conserved, as they are often used for development or human settlement. Excluding these will limit the dataset to meeting stricter conservation standards. Note that this is only relevant if using WDPA data.

- **Buffer protected area points:** the user can specify whether they want to buffer protected area points. For any protected areas that are represented as single points instead of polygons, this will create a circle around the polygon that is equal to the reported area. This will not affect the connectivity metrics if using centroids but may cause inaccuracies if assessing connectivity using the nearest edge. If left unchecked, all protected areas represented as points will be removed. Note that this is only relevant if using WDPA data.

- **Include marine protected areas:** the user can specify whether they want to include marine protected areas in the analysis or not. Note that the analysis is still limited to the bounds of the study area polygon. This input is only relevant if using WDPA data.

- **Include OECMs:** the user can specify whether they want to include other effective area-based conservation measures (OECMs) in the analysis or not. These areas are not officially designated protected areas but are still achieving conservation outcomes. This input is only relevant if using WDPA data.

### Pipeline steps

#### **1. Getting protected areas from World Database on Protected Areas (WDPA)**

This step retrieves protected areas in the country/region of interest from the WDPA database using the WDPA API. (This step is skipped if you are only using custom PA data).

#### **2. Getting the country polygon**

This step returns the polygon for the country/region of interest.

#### **3. Cleaning the protected areas data**

This step cleans the data retrieved from the WDPA by correcting any geometry issues and filtering by the desired inputs. This step also crops the protected areas by the study area (This step is skipped if you are only using custom PA data).

#### **3. Performing the ProtConn analysis**

This step performs the ProtConn analysis on the protected areas of interest. ProtConn is calculated by creating a pairwise matrix of the distances between each protected area. Then, it calculates the probability of a species dispersing between these protected areas using a negative exponential dispersal kernel with the input distance assigned to a probability of 0.5. This means that if the protected areas are very near one another, there is a high probability that species will be able to disperse between them, but this probability decays exponentially with increasing distance. Different dispersal distances can be specified based on the species of interest, as very small species such as rodents can not disperse as far as large mammals such as deer, so the connectedness would not be the same for those groups. Then, the dispersal probabilities between each of the protected areas are summed together, multiplied by the area of the protected areas, and divided by the area of the study area. Thus, ProtConn is the percentage of the total study area (country or region) that is protected with well-connected protected areas.

### Pipeline outputs

- **ProtConn results:** The pipeline gives a table with several measures
  - Unprotected - percentage of study area that is protected
  - ProtConn - percentage of the study area that is protected and connected
  - ProtUnconn - percentage of the study area that is protected and unconnected

- **Result plot:** donut plot of percentage of the study area that is protected and unconnected, and protected and connected.

- **ProtConn time series:** plot of ProtConn over time, based on the dates that protected areas were established and the specified dispersal distance.

## Example

**Sample run:** See an example ProtConn run here in the [run ui](https://pipelines-results.geobon.org/pipeline-form/Protconn-pipeline%3EProtConn_pipeline/1809e8c81dd453dd652d7904224e6522) and [viewer](https://pipelines-results.geobon.org/viewer/Protconn-pipeline%3EProtConn_pipeline%3E1809e8c81dd453dd652d7904224e6522).

## Troubleshooting

**Common errors:**

- `Error: Could not retrieve protected areas from WDPA`: if you encounter this error, it means the WDPA API is not able to retrieve the data for the country/region of interest. This sometimes happens with very large datasets and is a problem with the API itself, not the pipeline.

- `Error: Script produced no results. Check log for errors and make sure that the script calls biab_output.`: if you encounter this error and you are running ProtConn for a large area with many protected areas, it is likely that Docker has terminated the process because you have run out of computer RAM. You may need to run the analysis with smaller areas or on a computer with more RAM.

## References

Saura, Santiago, Lucy Bastin, Luca Battistella, Andrea Mandrici, and Grégoire Dubois. “Protected Areas in the World’s Ecoregions: How Well Connected Are They?” Ecological Indicators 76 (May 1, 2017): 144–58. https://doi.org/10.1016/j.ecolind.2016.12.047.

Saura, Santiago, Bastian Bertzky, Lucy Bastin, Luca Battistella, Andrea Mandrici, and Grégoire Dubois. “Protected Area Connectivity: Shortfalls in Global Targets and Country-Level Priorities.” Biological Conservation 219 (March 1, 2018): 53–67. https://doi.org/10.1016/j.biocon.2017.12.020.

Godínez-Gómez, O. and Correa Ayram C.A. 2020. Makurhini: Analyzing landscape connectivity. 10.5281/zenodo.3771605


