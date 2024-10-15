The Protected Connected Index (ProtConn) is a component indicator in the Global Biodiversity Framework (GBF). ProtConn measures the percent of a given country or region that is conserved and managed through well-connected protected areas. This is an important indicator for assessing progress towards goals A and Target 3 of the GBF, which aim to have 30% of land area protected by a network of well-connected protected areas by 2030. ProtConn can be used to assess current progress towards these goals and for protected area planning and design. 

**Methods:**
ProtConn is calculated by measuring the distances between protected areas and creating a matrix of these distances. Then, it calculates the probability of a species dispersing between these protected areas using a negative exponential dispersal kernel. This means that if the protected areas are very near one another, there is a high probability that species will be able to disperse between them, but this probability decays exponentially with increasing distance. Different dispersal distances can be specified based on the species of interest, as very small species such as rodents can not disperse as far as large mammals such as deer, so the connectedness would not be the same for those groups. Then, the dispersal probabilities between each of the protected areas are summed together, multiplied by the area of the protected areas, and divided by the area of the study area. Thus, ProtConn is the percentage of the total study area (country or region) that is protected with well-connected protected areas.

**BON in a Box Pipeline:**
BON in a Box has created a pipeline to calculate ProtConn for a given country or region of interest. The pipeline has the following user inputs:
* **Study area:** the user can specify a country or state/province and the pipeline will pull the polygon for this area. Alternatively, the user can upload a custom study area as a shapefile.
* **Protected areas:** the pipeline can pull data from the World Database of Protected Areas (WDPA) or can run with a shapefile of protected areas that is uploaded by the user. The pipeline can also combine protected areas from WDPA with a shapefile that is uploaded. 
* **Type of distance matrix:** The user can specify whether the distances between protected areas should be measured using the centroid, or center, of the protected area or the closest edge.
![Slide4](https://github.com/user-attachments/assets/8ffc8b34-8a1d-4101-ae82-c6e05ff160ae)
![Slide3](https://github.com/user-attachments/assets/1de25139-5933-44da-b6f9-6a02f6d4a815)
* **Dispersal distance:** the user can specify a dispersal distance depending on which species they are interested in. This will be the median of the negative dispersal kernel, meaning that at that distance, there will be a dispersal probability of 0.5.
![Slide2](https://github.com/user-attachments/assets/45857a20-80a8-4b0e-ab41-36f5ca40cba3)
* **Transboundary distance:** protected areas that are past the boundary of the study area can still contribute to connectedness. The user can specify the distance past the boundary of the study area where they want to include protected areas. The transboundary protected areas will not be included in the area measurement, but will be included in the measurement of connectedness.
![transboundary](https://github.com/user-attachments/assets/5d89c195-00b7-4915-bc17-20fdd6a28f9e)
* **Year:** the user can specify the year for which they want ProtConn calculated (defaults to the present year)
* **Study area ESPG:** the user can specify the coordinate reference system.
* **Start year, end year, and time interval:** The user can specify start and end years for ProtConn and the pipeline will create a time series of ProtConn values at the time interval specified

The pipeline creates the following outputs:
* **ProtConn results:** The pipeline gives a table with several measures
  * ProtConn - percentage of the study area that is protected and connected
  * ProtUnconn - percentage of the study area that is protected and unconnected
  * Etc.
* **Result plot:** donut plot of percentage of the study area that is unprotected, protected and unconnected, and protected and connected.
* **Result with standardized distances:** ProtConn results for 3 standardized dispersal distances (1km, 10km, and 100km) that cover common dispersal distances for a range of species.
* **Result plot with standardized distances:** donut plot of percentage of the study area that is unprotected, protected and unconnected, and protected and connected for each dispersal distance.
* **ProtConn time series:** plot of ProtConn over time, based on the dates that protected areas were established and the specified dispersal distance.

See an example ProtConn output here (coming soon).

**Contributors:**
* Jory Griffith
* Guillaume Larocque

**References:**
Saura, Santiago, Lucy Bastin, Luca Battistella, Andrea Mandrici, and Grégoire Dubois. “Protected Areas in the World’s Ecoregions: How Well Connected Are They?” Ecological Indicators 76 (May 1, 2017): 144–58. https://doi.org/10.1016/j.ecolind.2016.12.047.

Saura, Santiago, Bastian Bertzky, Lucy Bastin, Luca Battistella, Andrea Mandrici, and Grégoire Dubois. “Protected Area Connectivity: Shortfalls in Global Targets and Country-Level Priorities.” Biological Conservation 219 (March 1, 2018): 53–67. https://doi.org/10.1016/j.biocon.2017.12.020.

Godínez-Gómez, O. and Correa Ayram C.A. 2020. Makurhini: Analyzing landscape connectivity. 10.5281/zenodo.3771605



