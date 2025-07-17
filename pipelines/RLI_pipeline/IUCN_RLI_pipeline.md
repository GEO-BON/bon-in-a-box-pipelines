# Red List Index
### Author(s): Maria Camila Diaz, Victor Julio Rincon, Laetitia Tremblay
#### Reviewed by: In review

## Introduction

The Red List Index (RLI) shows trends in overall extinction risk for species, and is used to track progress towards reducing extinctions and biodiversity loss. RLI has been widely integrated into various policy frameworks. Initially used to assess progress towards the Convention on Biological Diversity’s 2010 target (Rodrigues, 2006), it has since been employed in regional, thematic, and global assessments by bodies such as the Intergovernmental Science-Policy Platform on Biodiversity and Ecosystem Services, the Global Environment Outlook, and others (Global Biodiversity Outlook, 2010).

### Uses

The RLI is a key indicator for the UN Sustainable Development Goals, particularly Goal 15, and is adopted by the Convention on Migratory Species and its agreements. It also serves as a headline indicator for Goal A and Target 4 of the CBD’s Kunming-Montreal Global Biodiversity Framework (CBD, 2022). Beyond global trends, the RLI can be used to track trends in species across different biogeographic realms, political units, ecosystems, habitats, taxonomic groups, and those relevant to various international agreements and treaties (Butchart et al., 2004; Butchart et al., 2005).

### Pipeline limitations

- On large or species-rich countries, this pipeline takes a significant amount of time to retrieve the data.

## Before you start

To use this pipeline, you’ll need an [IUCN token](https://api.iucnredlist.org/users/sign_up) to access data on the International Union for Conservation of Nature (IUCN) Red List of Threatened Species.

## Running the pipeline


### Pipeline inputs

The BON in a Box RLI pipeline allows you to calculate RLI for specific taxon groups and a country of interest. The inputs to the pipeline are:

- **Country:** The user can specify the country for which they want to calculate RLI.

- **Taxonomic group:** The user can specify the taxonomic group for which they want to calculate RLI using the drop-down menu.

### Pipeline steps

#### **1. Getting a list of species for the specified taxonomic group and country**

This step simultaneously retrieves a list of species assessed by the IUCN Red List of Threatened Species for the country of interest and the taxonomic group of interest, including their most recent threat categorization. This step will retrieve the full IUCN species list for the country and taxonomic group of interest, so it will take time even for a small country.

#### **2. Getting the history assessment for the species**

This step returns the history of assessments (year and assessment status) for every species in the list.

#### **3. Calculating the Red List Index**

This step calculates the Red List Index for the species in the list. Most species move between categories on the IUCN Red List due to improvements in knowledge or revised taxonomy, so merely looking at the number of species in each category over time is not a meaningful measure of overall changes in extinction risk. RLI was developed to reflect genuine improvement or deterioration in the status of individual species (Butchart et al., 2004; Butchart et al., 2005), and is calculated based on the proportion of species in each category on the Red List (Least Concern, Vulnerable, Endangered, etc.) and weighted by the proportion of the area that is in the country or region of interest. RLI can be calculated for all of the species in a given area, or separately for specific taxa (e.g. birds), or other specified groups (e.g. endemic species). The RLI values range between 0 (indicating all species are extinct) to 1 (indicating all species are Least Concern). For more detailed information on the RLI, visit the [IUCN website](https://www.iucnredlist.org/).

### Pipeline outputs

- **Country:** The country from which the species list was taken.

- **Taxonomic group:** The taxonomic group of the species that were assessed.

- **Red List data:** A dataset that describes the results of the RLI calculation.

- **Red List trend plot:** The Red List Index of species for the chosen taxonomy group over time. An RLI of 1 indicates that all species have a status of Least Concerned, while 0 indicates Extinct. If the RLI value is constant over time, the overall extinction risk remains unchanged. An upward trend shows a reduction in the rate of biodiversity loss.

- **Red List matrix:** A matrix of the threat categories of all the species of interest over time.

## Example

**Sample run:** See an example ProtConn run here in the [run ui](https://pipelines-results.geobon.org/pipeline-form/RLI_pipeline%3EIUCN_RLI_pipeline/46192f03723b43152495c84ac15175cf) and [viewer](https://pipelines-results.geobon.org/viewer/RLI_pipeline%3EIUCN_RLI_pipeline%3E46192f03723b43152495c84ac15175cf).

## Troubleshooting

**Common errors:**

- `HTTP 404 Not Found`: this error indicates a failure to connect to the IUCN Red List API. This is typically because the IUCN token provided is not valid.

## References

Butchart SHM, Stattersfield AJ, Bennun LA, Shutes SM, Akçakaya HR, et al. 2004. Measuring global trends in the status of biodiversity: Red List Indices for birds. PLoS Biology 2: e383.

Butchart SHM, Stattersfield AJ, Baillie JEM, Bennun LA, Stuart SN, et al. 2005. Using Red List Indices to measure progress towards the 2010 target andbeyond. Philosophical Transactions of the Royal Society of London B 360: 255–268.

Butchart SH, Resit Akçakaya H, Chanson J, Baillie JE, Collen B, et al. 2007. Improvements to the Red List Index. PLOS ONE 2(1): e140.
Cardoso, P., Branco, V. 2023. IUCN Redlisting Tools (Package red).

CBD 2022. Proposed monitoring framework for the post-2020 global biodiversity framework. CBD: Convention on Biological Diversity.
Global Biodiversity Outlook. 2010. Global biodiversity outlook 3. In Montréal, Canada: Secretariat of the Convention on Biological Diversity.(http://gbo3.cbd.int/) Phil. Trans. R. Soc. B (Vol. 9).
Rodrigues ASL, Pilgrim JD, Lamoreux JF, Hoffmann M, Brooks TM.2006. The value of the IUCN Red List for Conservation. Trends in Ecology & Evolution 21: 71–76.


