The [Species Habitat Index](https://geobon.org/ebvs/indicators/species-habitat-index-shi/) (SHI) is a component indicator for the Global Biodiversity Framework (GBF). SHI measures changes in ecological integrity by measuring the change in the quality and connectivity of habitats for species of interest. SHI is an important indicator for assessing progress towards Goal A of the GBF, which calls for the enhanced integrity of natural ecosystems. Read more about how SHI can be used to assess progress toward goal A here ([https://cdn.mol.org/static/files/indicators/habitat/WCMC-species\_habitat\_index-15Feb2022.pdf](https://cdn.mol.org/static/files/indicators/habitat/WCMC-species_habitat_index-15Feb2022.pdf)). 

**Methods:**

The Species Habitat Index (SHI) is the measurement of change in area and connectivity of suitable areas relative to a baseline. It is a composite of Species Habitat Scores (SHS), which measure the change in suitable area for a single species of interest. It is calculated in the BON in a Box pipeline by taking species range maps,  information about elevational ranges and IUCN habitat categories to determine the suitable area for the species. Then, the pipeline uses the Global Forest Watch (GFW) data (other land cover layers and options for inputting user data will soon be added) to calculate the area and connectivity scores by species. For the area score using GFW data, only forest species are recommended to be used and a starting year no earlier than 2000\. Forest loss is detected by year and subtracted from the initial 2000 forest layer distributed within the range map of the species and filtered by elevation ranges. This layer is then used to create a raster with the distances to habitat edges and the mean value for the area is used as the connectivity score. The habitat and connectivity score are combined to form the SHS. To calculate SHI, the SHS for each species is averaged and to calculate Steward’s SHI, this is also weighted by the proportion of the species’ range that is in the study area.

**BON in a Box pipeline:**

BON in a Box has a pipeline to calculate SHS and SHI for species, countries, and regions of interest. The pipeline has the following user inputs:

* **Study area:** the user can specify a country and state/province of interest or upload a custom study area polygon.  
* **Study area buffer:** To avoid having edge effects in calculations, a buffer is used to the limit the area of study. It is calculated by assuming the study area is approximately a circle and is equivalent to half the radius.   
* **Species:** The user can input the scientific name of a single species or multiple species of interest. Note that the SHS pipeline can only accept one species.  
* **Range map:** The user can choose to extract species range maps from IUCN, Map of Life, the Quebec species database (Quebec only) or upload a custom range map as a raster file. The type of range map file can also be specified.  
* **Spatial reference system:** The user can specify a CRS that is most accurate for their study area.  
* **Min and max forest:** The user specifies the forest cover that is preferred by the species.  
* **Initial time, final time, and time step:** The user can specify what year they want to use as the reference year, the time interval at which they want to measure SHI, and the final year.  
* **Output spatial resolution:** The user can specify the spatial resolution at which they want to measure habitat change  
* **Filter for elevation:** The user can decide whether they want to include elevation in the range map of the species of interest. If “yes” is chosen, the pipeline will extract the species elevation preferences from IUCN and remove areas within the range map that are outside of the elevational range of the species. The user can also specify a buffer to the elevation values.

The pipeline creates the following outputs:

* **SHS table:** The user can download tables of the SHS over time as csv files.  
* **SHI table:** The user can view the time series of SHI values and download results as a csv.  
* **SHS time series plot:** Plot of the connectivity score, habitat score, and SHS over time. The pipeline outputs separate plots for each species.  
* **SHI time series plot:** Plot of the composite SHI score over time.  
* **Steward’s SHI time series plot:** Plot of Steward’s SHI over time. Steward’s SHI is weighted by the proportion of the species’ range that is in the study area.  
* **Habitat by time step:** Raster maps of the habitat for each time point.  
* **Raster plot of forest change:** Maps areas that have lost habitat, gained habitat, and experienced no change over the specified time period.

See an example SHI output here: (coming soon)

Workflow for Species Habitat Score
![image2](https://github.com/user-attachments/assets/3ddb7aa8-14e8-49eb-93a8-8c26129e0fc8)

Multiple SHS are then combined into a Species Habitat Index
![image1](https://github.com/user-attachments/assets/2a7776ba-46c7-4100-b253-34843abf3a44)

**Contributors:** 
- Maria Isabel Arce-Plata
- Guillaume Larocque
- Jaime Burbano-Girón
- Maria Camila Díaz
- Timothée Poisot
- Jory Griffith
- Jean-Michel Lord

**References:**

Brooks, T. M., Pimm, S. L., Akçakaya, H. R., Buchanan, G. M., Butchart, S.  H. M., Foden, W., Hilton-Taylor, C., Hoffmann, M., Jenkins, C. N., Joppa, L., Li, B. V., Menon, V., Ocampo-Peñuela, N., & Rondinini, C. (2019). Measuring Terrestrial Area of Habitat (AOH) and Its Utility for the IUCN Red List. Trends in Ecology & Evolution, 34(11), 977–986. [https://doi.org/10.1016/j.tree.2019.06.009](https://doi.org/10.1016/j.tree.2019.06.009)

Jetz, W., McGowan, J., Rinnan, D. S., Possingham, H. P., Visconti, P., O’Donnell, B., & Londoño-Murcia, M. C. (2022). Include biodiversity representation indicators in area-based conservation targets. Nature Ecology & Evolution, 6(2), 123–126. [https://doi.org/10.1038/s41559-021-01620-y](https://doi.org/10.1038/s41559-021-01620-y) 
