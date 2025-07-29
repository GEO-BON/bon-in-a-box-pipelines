# Species Habitat Index and Species Habitat Score
### Author(s): Maria Isabel Arce-Plata, Guillaume Larocque, Jaime Burbano-Girón, Maria Camila Díaz, Timothée Poisot, Jory Griffith, Jean-Michel Lord
#### Reviewed by: In review

## Introduction
The [Species Habitat Index](https://geobon.org/ebvs/indicators/species-habitat-index-shi/) (SHI) is a component indicator for the Global Biodiversity Framework (GBF). SHI measures changes in ecological integrity by measuring the change in the quality and connectivity of habitats of species. It is a composite of Species Habitat Scores (SHS), which measure the change in suitable area for a single species of interest. It is calculated in the BON in a Box pipeline by taking species range maps, information about elevational ranges and IUCN habitat categories to determine the suitable area for the species. Then, the pipeline uses the Global Forest Watch (GFW) data (other land cover layers and options for inputting user data will soon be added) to calculate the area and connectivity scores by species. Forest loss is detected by year and subtracted from the initial 2000 forest layer distributed within the range map of the species and filtered by elevation ranges. This layer is then used to create a raster with the distances to habitat edges and the mean value for the area is used as the connectivity score. The habitat and connectivity score are combined to form the SHS. To calculate SHI, the SHS for each species is averaged and to calculate Steward’s SHI, this is also weighted by the proportion of the species’ range that is in the study area.

## 'Use Case'/Context
SHI is an important indicator for assessing progress towards Goal A of the GBF, which calls for the enhanced integrity of natural ecosystems. Read more about how SHI can be used to assess progress toward goal A here ([https://cdn.mol.org/static/files/indicators/habitat/WCMC-species_habitat_index-15Feb2022.pdf](https://cdn.mol.org/static/files/indicators/habitat/WCMC-species_habitat_index-15Feb2022.pdf)).

## Pipeline limitations
Currently, the pipeline uses only Global Forest Watch data to measure change in habitat, so the pipeline is limited to calcualting SHS and SHI for forest species.

## Before you start
To use this pipeline, you’ll need an [IUCN token](https://api.iucnredlist.org/users/sign_up) to access data on the International Union for Conservation of Nature (IUCN) species range polygons.

## Running the pipeline

### Pipeline inputs
BON in a Box has a pipeline to calculate SHS and SHI for species, countries, and regions of interest. The pipeline has the following user inputs:

- **Species:** List of scientific names of species for which you want to calculate the SHI index.

- **Study area option:** Whether the study area of interest is a country, region, or a user provided polygon.

- **Country:** Country of interest to be used as study area. Check the available countries and regions [here](https://www.naturalearthdata.com/downloads/10m-cultural-vectors/).

- **Region:** Region of interest to be used as study area. To be used when you want more specific administrative boundaries. Check the available countries and regions [here](https://www.naturalearthdata.com/downloads/10m-cultural-vectors/).

- **Study area:** Polygon of the study area, in geopackage format. Input the path to the file in userdata (e.g. /userdata/study_area_polygon.gpkg). To be used when the `Study area option` input is selected to be *user defined*.

- **Buffer for study area:** Size of the buffer around the study area. To avoid having edge effects in calculations, a buffer is used to the limit the area of study. Defaults to half of the total width of the study area.

- **Type of range map:** Used to select the type of range map. This is based on the type of the source file chosen or provided, where the source file can be a polygon, raster, or both.

- **Source of expert range map:** Source from which to get the expert range map for the species of interest. The options are: Map of Life (MOL), International union for conservation of nature (IUCN) and range maps from the Ministère de l’Environnement du Québec (QC).

- **Range map (raster):** Raster with the expected area for the species of interest. To be used when the `Type of range map` input is selected to be *Raster*.

- **Spatial reference system:** Reference system for the area of interest. It can be 1) the Spatial Reference System Identifier (SRID), 2) the authority name (e.g. EPSG) with the SRID or 3) the description of the spatial reference system details (e.g. [https://spatialreference.org/]). If just the SRID is given and the software can not find the reference system try options 2 or 3.

- **Min forest:** Minimum tree cover percentage required for each species, based on suitable habitat of the species. Acts as a filter for the Global Forest Watch Data. If not available, use Map of Life Values (e.g. [https://mol.org/species/range/Myrmecophaga-tridactyla]). For multiple species, input in the same order as the input in species and separate with a comma.

- **Max forest:** Maximum tree cover percentage required for each species, based on suitable habitat of the species. Acts as a filter for the Global Forest Watch Data. If not available, use Map of Life Values (e.g. [https://mol.org/species/range/Myrmecophaga-tridactyla]). For multiple species, input in the same order as the input in species and separate with a comma.

- **Initial time:** Year at which the analysis should begin, must be 2000 or later. Check the time interval available for the Global Forecst Watch data [here](https://stac.geobon.org/collections/gfw-lossyear).

- **Final time:** Year at which the analysis should end, must be a later than the `Initial time` input. It should be within the time interval for the Global Forest Watch (GFW) data which can be found [here](https://stac.geobon.org/collections/gfw-lossyear).

- **Time step:** Temporal resolution for analysis, in number of years. To get values for the end year, the time step should fit evenly into the given analysis range.

- **Output spatial resolution:** The user can specify the spatial resolution at which they want to measure habitat change.

- **Filter by elevation:** The user can decide whether they want to include elevation in the range map of the species of interest. If “yes” is chosen, the pipeline will extract the species elevation preferences from IUCN and remove areas within the range map that are outside of the elevational range of the species. The user can also specify a buffer to the elevation values.

- **Elevation buffer:** Elevation buffer (in meters) to be added or subtracted to the reported species elevation range. Default is zero. Positive values will increase the range by that number in meters, while negative values will decrease the range by that number.

### Pipeline steps

#### **1. Getting the species range map**
This step downloads the range map for the species of interest from the expert source chosen (ICUN, MOL, or QC).

#### **2. Getting the area of habitat**
This step calculates the area of habitat for the species of interest.

#### **3. Measuring habitat change**
This step uses the area of habitat of the species of interest with GFW layers to measure changes in the habitat of the species. It uses the 2000 forest layer as a reference and removes the pixels from the loss layer of GFW data.

#### **4. Calculating the SHI index**
This steps calculate the Species Habitat Index (SHI) for the species of interest. The SHI is the measurement of change in area and connectivity of suitable areas relative to a baseline. It is a composite of Species Habitat Scores (SHS), which measure the change in suitable area for a single species of interest. It is calculated in the BON in a Box pipeline by taking species range maps, information about elevational ranges and IUCN habitat categories to determine the suitable area for the species. Then, the pipeline uses the Global Forest Watch (GFW) data (other land cover layers and options for inputting user data will soon be added) to calculate the area and connectivity scores by species. For the area score using GFW data, only forest species are recommended to be used and a starting year no earlier than 2000. Forest loss is detected by year and subtracted from the initial 2000 forest layer distributed within the range map of the species and filtered by elevation ranges. This layer is then used to create a raster with the distances to habitat edges and the mean value for the area is used as the connectivity score. The habitat and connectivity score are combined to form the SHS. To calculate SHI, the SHS for each species is averaged and to calculate Steward’s SHI, this is also weighted by the proportion of the species’ range that is in the study area.

### Pipeline outputs

- **Species:** List of the species of interest for which the SHI was calculated.

- **Expert range map:** Polygon of expected area for the species of interest.

- **Habitat by time step:** Raster maps of the habitat for each time point.

- **Raster plot of forest change:** Maps areas that have lost habitat, gained habitat, and experienced no change, over the specified time period.

- **SHS table:** A TSV file containing Area Score, Connectivity Score and SHS by time step for each species. Percentage of change, 100% being equal to the reference year.

- **SHS map:** Figure showing a map with changes in the habitat over time, for each species.

- **SHS time series:** Plot of the connectivity score, habitat score, and SHS over time. The pipeline outputs separate plots for each species.

- **SHI table:** Table with SHI and Steward’s SHI values for the complete area of study.

- **SHI time series:** Plot of the composite SHI score over time, 100% being equal to the reference year.

- **Steward's SHI time series:** Plot of Steward’s SHI over time. Steward’s SHI is weighted by the proportion of the species’ range that is in the study area.

## Example
**Sample run:** See an example SHI run here in the [run ui](https://pipelines-results.geobon.org/pipeline-form/SHI_pipeline/fb4b651c9c810117b3e8338085a009e2) and [viewer](https://pipelines-results.geobon.org/viewer/SHI_pipeline%3Efb4b651c9c810117b3e8338085a009e2).

## Troubleshooting

## References
Brooks, T. M., Pimm, S. L., Akçakaya, H. R., Buchanan, G. M., Butchart, S. H. M., Foden, W., Hilton-Taylor, C., Hoffmann, M., Jenkins, C. N., Joppa, L., Li, B. V., Menon, V., Ocampo-Peñuela, N., & Rondinini, C. (2019). Measuring Terrestrial Area of Habitat (AOH) and Its Utility for the IUCN Red List. Trends in Ecology & Evolution, 34(11), 977–986. [https://doi.org/10.1016/j.tree.2019.06.009](https://doi.org/10.1016/j.tree.2019.06.009)

Jetz, W., McGowan, J., Rinnan, D. S., Possingham, H. P., Visconti, P., O’Donnell, B., & Londoño-Murcia, M. C. (2022). Include biodiversity representation indicators in area-based conservation targets. Nature Ecology & Evolution, 6(2), 123–126. [https://doi.org/10.1038/s41559-021-01620-y](https://doi.org/10.1038/s41559-021-01620-y)



