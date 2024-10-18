The Biodiversity Intactness Index (BII) is a metric designed to assess the degree to which ecosystems are intact and functioning relative to their natural state. It measures the abundance and diversity of species in a given area compared to what would be expected in an undisturbed ecosystem. The BII accounts for various factors, including habitat loss, fragmentation, and degradation, providing a comprehensive view of biodiversity health. A higher BII value indicates a more intact ecosystem with greater species diversity and abundance, while a lower value suggests significant ecological disruption. The biodiversity intactness index is a complimentary indicator in the GBF. 

**Methods:**
The BII is created by the Natural History Museum and uses their PREDICTS database, which aggregates data from studies comparing terrestrial biodiversity at sites experiencing varying levels of human pressure. It currently contains over 3 million records from more than 26,000 sites across 94 countries, representing a diverse array of over 45,000 plant, invertebrate, and vertebrate species. The BII uses the PREDICTS database to establish a reference state using the biodiversity patterns in habitats with minimal disturbance levels. Then, it assigns sensitivity scores to each species based on their vulnerability to human pressure. Intactness is calculated by comparing the observed species abundance in a given area to what is expected under reference conditions with low human impact. 

**The BON in a Box pipeline:**
The Natural History Museum has created raster layers of BII since the year 2000. BON in a Box has a pipeline to calculate summary statistics and plot a time series from these layers in a country, region, or custom study area of interest. The pipeline has the following inputs:
* **Country:** The user can input a country of interest for which they want to calculate BII summary statistics.
* **Region:** The user can specify a state or province of interest for which they want to caluculate BII summary statistics.
* **File for study area:** The user can upload a custom study area file as a polygon instead of specifying a country or region.
* **Summary statistic:** The user can choose the summary statistic for BII (options: mean, median, mode) that will be calculated for the country or region of interest.
* **Start and end year for BII raster comparison:** The user can specify two years for which they want to compare BII. The pipeline will create a raster layer of BII change.

The pipeline has the following outputs:
* **Time series plot:** A time series plot of the chosen summary statistic over years for the country or region of interest.
* **Summary statistic:** A table of the summary statistic values of BII over years. This can be downloaded as a CSV file.
* **Rasters:** The user can view all of the raster layers for each year that were used to generate the summary statistics.
* **Change in BII:** A raster plot of the change in BII between the two chosen years.

**Contributors:**
* Jory Griffith (https://orcid.org/0000-0001-6020-6690)

**Citations:**
Adriana De Palma; Sara Contu; Gareth E Thomas; Connor Duffin; Sabine Nix; Andy Purvis (2024). The Biodiversity Intactness Index developed by The Natural History Museum, London, v2.1.1 (Open Access, Limited Release) [Data set]. Natural History Museum. https://doi.org/10.5519/k33reyb6

Newbold, T., Hudson, L. N., Arnell, A. P., Contu, S., De Palma, A., Ferrier, S., Hill, S. L. L., Hoskins, A. J., Lysenko, I., Phillips, H. R. P., Burton, V. J., Chng, C. W. T., Emerson, S., Gao, D., Pask-Hale, G., Hutton, J., Jung, M., Sanchez-Ortiz, K., Simmons, B. I., … Purvis, A. (2016). Has land use pushed terrestrial biodiversity beyond the planetary boundary? A global assessment. Science, 353(6296), 288–291. https://doi.org/10.1126/science.aaf2201
