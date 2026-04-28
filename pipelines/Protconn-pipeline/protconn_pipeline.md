_Authors: Jory Griffith, Guillaume Larocque, Laetitia Tremblay, Jean-Michel Lord_

Review status: Reviewed

Reviewed by: Santiago Saura, Oscar Godinez-Gomez, Camilo Andreas Correa Ayram, Teresa Goicolea


name: Protected Connected Index (ProtConn)
description: >-

## Introduction

The Protected Connected Index (ProtConn) is a key indicator within the Kunming-Montreal Global Biodiversity Framework (GBF) to assess progress toward Goal A and Target 3, which aims to protect 30% of the planet through well-connected networks by 2030. ProtConn quantifies the percentage of a country or region where protected areas are effectively connected, allowing for species movement and ecological flow.

ProtConn measures how well a region is protected and connected (Saura et al. 2017, 2018). ProtConn is calculated by evaluating the spatial arrangement of protected areas to determine how easily species can move between them across a landscape. It treats protected areas as "nodes" and potential movement between them as "links", measuring the probability that a species with a given dispersal distance will be able to travel between protected areas. This probability is calculated between the nearest edges of adjacent protected areas using a negative exponential dispersal kernel, where the input dispersal distance is the median (that is, where dispersal probability is 0.5). The final ProtConn value is expressed as a percentage of the total study area, partitioned into percentages that account for connectivity within PAs, between different PAs, and across international borders. To learn more about the ProtConn method, see Saura et al. 2017, 2018, and 2019.

The pipeline uses the ‘Makurhini’ package (Godinez-Gomez et al. 2026) to calculate ProtConn metrics. The pipeline can be run with data from the World Database of Protected Areas (UNEP-WCMC and IUCN 2026) pulled for a specific country or region within the pipeline, custom shapefiles of protected areas uploaded by the user, or a combination of both. This allows users to evaluate ProtConn both currently and with the addition of proposed future protected areas. ProtConn can be calculated at the country or region level.

## Uses

ProtConn can be used to assess current progress toward Goal A and Target 3 of the GBF. The pipeline can also be used to compare the connectedness of different proposed protected areas, assisting with planning and design. The pipeline can be run with a combination of current protected areas from WDPA and user-input polygons of proposed protected area sites, allowing users to evaluate different plans for protected area expansion.

## Pipeline limitations

* On larger datasets, the pipeline is slow and uses a lot of memory, especially with larger input dispersal distances.

* Currently, the pipeline does not take into account landscape resistance (i.e., whether land between protected areas is easily traversed by species).

## Before you start

No API keys are needed to run this pipeline.

If you would like to run the pipeline with a custom polygon for your study area, input your file path starting from the user data folder into the "polygon of study area" input box.

If you would like to run the pipeline with a combination of custom protected area polygons and WDPA data, ensure your data is in GeoPackage format and input the file path into the "polygon of protected areas" input.

If you want to run the analysis with custom protected area data only, please use the `ProtConn Analysis with custom PAs` pipeline.


## Running the pipeline

### Pipeline inputs

BON in a Box contains a pipeline to calculate ProtConn for a given country or region of interest. The pipeline has the following user inputs:

- **Bounding Box and CRS:** the user must select a bounding box and coordinate reference system (CRS) to be used for the analysis. This can be done by using the chooser to either select a country and/or region, or type in/draw a custom bounding box. Then, an appropriate CRS can be selected from the corresponding drop-down menu. **The CRS must be projected.**

- **Polygon of study area:** this is an optional input to add a custom study area file, which will override the polygon generated from the Bounding Box and CRS input. The custom study area file must be in GeoPackage format and added to the userdata folder in your local repository. This input should be the path to the file in userdata (e.g. /userdata/study_area_polygon.gpkg).

- **Polygon of protected areas:** this is an optional input and should only be used if the user wants to use custom protected area data, for example if they want to calculate ProtConn for proposed protected areas or protected areas that are not yet in WDPA. If you use the `ProtConn Analysis with WDPA` pipeline, this input is optional and any file added will be combined with WDPA data of the country of interest. If you use the `ProtConn Analysis with custom PAs` pipeline, this input is mandatory and the pipeline will analyze only user-input protected area polygons.

- **Transboundary Buffer:** the user must select a buffer for pulling transboundary protected areas. The buffer will pull protected areas within that distance of the country border or bounding box in the unit of the coordinate reference system. If pulling WDPA data with a custom bounding box, the buffer will not be applied. It is recommended that the user chooses a transboundary distance 5 times greater than the largest distance threshold, which corresponds to a dispersal probability of ~0.03. The default value is zero.

- **Date Column Name:** this is an optional input to be used with a custom protected area data file. The user can indicate the name of the column in the file that specifies when the protected area was created (leave blank if only using WDPA data).

- **Distance analysis threshold:** the user can specify one or more dispersal distances depending on which species they are interested in. Common dispersal distances are 1,000 meters (1km), 10,000 m (10km) and 100,000 m (100 km). The dispersal distance is the median of the negative exponential dispersal kernel, meaning that at that distance there is a dispersal probability of 0.5. Note that larger dispersal distances will be more computationally intensive.

  ![Dispersal probability](https://github.com/user-attachments/assets/5a867368-12a3-4402-aa1d-a034b9dc7962)

- **Time series:** the user can specify whether they want to calculate a time series plot of ProtConn values based on date of PA establishment. Omitting the time series reduces memory and computational costs.

- **Start year:** the start year of the time series of ProtConn values. The time series will calculate ProtConn for the protected areas established on or before the chosen year, and will count up to the cutoff year by the specified interval. Any missing dates in the protected area file will be automatically assigned to this year. This can be left blank or will be ignored if the time series option was not selected.

- **Year for cutoff:** the user can specify a year for the analysis. The analysis will only calculate values for protected areas that were established before this cutoff year. For example, an input of 2000 will calculate ProtConn only for PAs that were designated before the year 2000.

- **Year interval:** the year interval for the time series of ProtConn values. For example, an input of 10 will calculate ProtConn values every 10 years. This can be left blank or will be ignored if the time series option was not selected.

- **PA size threshold:** the user must input a size threshold for PAs, in square meters. Protected areas smaller than this area will be removed. A threshold of 1,000 m2 was used in Saura et al. 2017 because at larger scales, protected areas less than 1,000 m2 do not have a large impact on ProtConn values. Removing small protected areas significantly speeds up calculation and is recommended for large areas. To avoid filtering PAs by size threshold, input a value of 0.

- **PA legal status types to include:** the user can choose legal status types of WDPA data to include in the analysis. This input is only relevant if using WDPA data. The protected areas can have a legal status of `Proposed`, `Inscribed`, `Adopted`, `Designated`, or `Established`.
- `Proposed` means that the site is in the process of gaining recognition through legal or other effective means. It may still be managed as a protected area during this process.
- `Inscribed` means that it is inscribed in an international list (e.g., World Heritage). This can overlap with designated.
- `Adopted` means that it is a specially protected area of marine importance (SPAMI) created under the Barcelona Convention, focusing on the protection of the marine environment and coastal regions of the Mediterranean.
- `Designated` means that it is officially established under national or international law/policy.
- `Established` means that it is protected and managed, but possibly lacks formal legal designation.

- **Include UNESCO Biosphere reserves:** the user can specify whether they want to include UNESCO Man and the Biosphere reserves in the analysis or not. These serve as learning sites for sustainable development and combine biodiversity conservation with the sustainable use of natural resources and sustainable development. They may not be legally protected and may not be fully conserved, as they are often used for development or human settlement. Excluding these will limit the dataset to meeting stricter conservation standards. This input is only relevant if using WDPA data.

- **Buffer protected area points:** the user can specify whether they want to buffer protected area points. For any protected areas represented as single points instead of polygons, this will create a circle around the point that is equal to the reported area. If left unchecked, all protected areas represented as points will be removed. This input is only relevant if using WDPA data.

- **Include OECMs:** the user can specify whether they want to include other effective area-based conservation measures (OECMs) in the analysis or not. These areas are not officially designated protected areas but are still achieving conservation outcomes. This input is only relevant if using WDPA data.

- **Include marine and coastal protected areas:** the user can specify whether they want to include marine protected areas in the analysis or not. Note that the analysis is still limited to the bounds of the study area polygon. This input is only relevant if using WDPA data.

- **Include missing values for date:** the user can specify how missing values for date should be handled in the time series analysis. If the box is checked, protected areas with missing values for establishment date will be included in the time series analysis and assigned to the chosen value for start year. If not checked, these protected areas will be omitted from the time series analysis (note they will still be included in the main analysis).

### Pipeline steps

#### **1. Getting protected areas from World Database on Protected Areas (WDPA)**

This step retrieves protected areas in the country/region of interest from the WDPA database using the WDPA API. (This step is skipped if you are only using custom PA data.)

#### **2. Getting the polygon of the area of interest**

This step returns the polygon for the country/region/area of interest. If a country/region was selected, it pulls the country/region polygon using [Fieldmaps](https://fieldmaps.io/) and outputs it as a GeoPackage projected in the CRS of interest. If the user inputs a custom bounding box, it returns a polygon made from that bounding box.

#### **3. Cleaning the protected areas data**

This step cleans the data retrieved from the WDPA by correcting any geometry issues and filtering by the desired inputs. This step also crops the protected areas by the study area (this step is skipped if you are only using custom PA data).

#### **4. Performing the ProtConn analysis**

This step performs the ProtConn analysis on the protected areas of interest. ProtConn is calculated by creating a pairwise matrix of the distances between the closest edges of each protected area. Then, it calculates the probability of a species dispersing between these protected areas using a negative exponential dispersal kernel with the input distance assigned to a probability of 0.5. This means that if the protected areas are very near one another, there is a high probability that species will be able to disperse between them, but this probability decays exponentially with increasing distance. Different dispersal distances can be specified based on the species of interest, as very small species such as rodents cannot disperse as far as large mammals such as deer, so the connectedness would not be the same for those groups. Then, the dispersal probability between each pair of protected areas is multiplied by the area of the protected areas, and the result of this product is summed for all pairs and divided by the area of the study area.

### Pipeline

- **Protected areas:** protected areas on which ProtConn is being calculated. Overlapping protected areas have been merged into one to speed up calculations.

- **ProtConn results:** the pipeline gives a table with several measures:
  - Unprotected - percentage of study area that is not covered by a protected area
  - ProtConn - percentage of the study area that is covered by well-connected protected areas
  - ProtUnconn - percentage of the study area that is covered by protected areas that are not well connected
  - ProtConn_Unprot - Percentage of the protected connected land that can be reached by moving through unprotected areas. It includes movements between PAs that entirely happen through unprotected lands and others that traverse unprotected lands in the initial and final stretches but that may use some protected land in between. The value of this fraction will be lower when PAs are separated by larger tracts of unprotected lands, making inter-PA movements less likely, particularly when the distances that need to be traversed through unprotected lands are large compared to the dispersal distance.
  - ProtConn_Within - Percentage of the protected connected land that can be reached by moving only within individual PAs
  - ProtConn_Contig - Percentage of the protected connected land that can be reached by moving through sets of immediately adjacent (contiguous) PAs without traversing any unprotected lands.

- **ProtConn result plot:** donut plot of percentage of the study area that is protected and unconnected, and protected and connected for each input dispersal distance (in meters).

- **ProtConn time series results:** table of the time series of ProtConn and ProtUnconn values, calculated at the time interval that is specified.

- **ProtConn time series plot:** plot showing the change in the percentage area that is protected and the percentage that is protected and connected over time, at the chosen time interval, compared to the Kunming-Montreal GBF goals.

- **Study area polygon:** polygon of the chosen study area.

## Example

**Sample run:**

Example of a pipeline run with WDPA data: [insert link]

Example of a pipeline run with user data: [insert link]

Example of a pipeline run with both user data and WDPA data: [insert link]

## Troubleshooting

**Common errors:**

- `Error: Could not retrieve protected areas from WDPA`: if you encounter this error, it means the WDPA API is not able to retrieve the data for the country/region of interest. This sometimes happens with very large datasets and is a problem with the API itself, not the pipeline.

- `Error: Script produced no results. Check log for errors and make sure that the script calls biab_output.`: if you encounter this error and you are running ProtConn for a large area with many protected areas, it is likely that Docker has terminated the process because you have run out of computer RAM. You may need to run the analysis with smaller areas or on a computer with more RAM.

## References

Godínez-Gómez, O., Correa Ayram, C.A., Goicolea, T., Saura, S. 2026. Makurhini: An R package for comprehensive analysis of landscape fragmentation and connectivity. Environmental Modelling & Software. https://doi.org/10.1016/j.envsoft.2026.106981. 

Saura, Santiago, Lucy Bastin, Luca Battistella, Andrea Mandrici, and Grégoire Dubois. 2017. “Protected Areas in the World’s Ecoregions: How Well Connected Are They?” Ecological Indicators 76:144–58. doi:10.1016/j.ecolind.2016.12.047.

Saura, Santiago, Bastian Bertzky, Lucy Bastin, Luca Battistella, Andrea Mandrici, and Grégoire Dubois. 2018. “Protected Area Connectivity: Shortfalls in Global Targets and Country-Level Priorities.” Biological Conservation 219:53–67. doi:10.1016/j.biocon.2017.12.020.

Saura, Santiago, Bastian Bertzky, Lucy Bastin, Luca Battistella, Andrea Mandrici, and Grégoire Dubois. 2019. “Global Trends in Protected Area Connectivity from 2010 to 2018.” Biological Conservation 238:108183. doi:10.1016/j.biocon.2019.07.028.

UNEP-WCMC and IUCN (2026), Protected Planet: The World Database on Protected Areas (WDPA), Cambridge, UK: UNEP-WCMC and IUCN.



