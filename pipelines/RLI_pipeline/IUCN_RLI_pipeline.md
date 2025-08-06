# Red List Index
Author(s): Maria Camila Diaz, Victor Julio Rincon, Laetitia Tremblay, Jory Griffith
#### Reviewed by: In review

## Introduction

The Red List Index (RLI) shows trends in overall extinction risk for species, and is used to track progress towards reducing extinctions and biodiversity loss. Many species that move categories in the Red List do so because of revised taxonomy or improved knowledge. Therefore, looking at raw trends in Red List status can be misleading. RLI models these trends to show overall changes the status of species groups that are based only on genuine improvement or deterioriation. 

RLI has been widely integrated into various policy frameworks. Initially used to assess progress towards the Convention on Biological Diversity’s 2010 target (Rodrigues, 2006), it has since been employed in regional, thematic, and global assessments by bodies such as the Intergovernmental Science-Policy Platform on Biodiversity and Ecosystem Services (IPBES), the Global Environment Outlook, and others (Global Biodiversity Outlook, 2010).

### Uses

The RLI is a key indicator for the UN Sustainable Development Goals, particularly Goal 15, and is adopted by the Convention on Migratory Species and its agreements. It also serves as a headline indicator for Goal A and Target 4 of the CBD’s Kunming-Montreal Global Biodiversity Framework (CBD, 2022). Furthermore, by tracking the proportion of threatened species showing status improvement, the RLI plays a central role in evaluating progress toward Goal A. Beyond global trends, the RLI can be used to track changes in extinction risk across biogeographic realms, political units, ecosystems, habitats, taxonomic groups, threat types, use or trades, and those relevant to various international agreements and treaties (Butchart et al., 2004; Butchart et al., 2005). The RLI supports progress towards several other goals and targets within the framework, such as Goal B, Target 2, and Target 5, highlighting changes in extinction risk, including for utilized species. By calculating the RLI in more specific contexts, such as for species impacted by pollution (Target 7), species affected by invasive alien species (Target 6b), or those used for food and medicine (Target 9b), the indicator provides targeted insights that directly inform efforts to meet these goals.

The following are suggested inputs that are goal-specific:

**1. RLI of species impacted by pollution (Target 7)**

- Country: User's choice
- Taxonomic group: All
- Threat category: Pollution
- Species use: Do not filter by species use or trade

**2. RLI of species impacted by invasive alien species (Target 6b)**

- Country: User's choice
- Taxonomic group: All
- Threat category: Invasive alien species or diseases
- Species use: Do not filter by species use or trade

**3. RLI of species used in food and medicine (Target 9b)**

- Country: User's choice
- Taxonomic group: All
- Threat category: Do not filter by threat category
- Species use: Food - human, Food - animal, Medicine - human & veterinary

**4. RLI for all utilized species (Targer Bb and Goal 5)**

- Country: User's choice
- Taxonomic group: All
- Threat category: Do not filter by threat category
- Species use: All

### Pipeline limitations

- On large or species-rich countries, as well as in threat or use categories that have a substantial number of species, this pipeline takes a significant amount of time to retrieve the data.

- This pipeline calculates the RLI for species only. Subspecies, subpopulations, and varieties are excluded from the analysis.

- The list of IUCN assessments extracted for this pipeline are only the ones done on a Global scale. Regional scale assessments are excluded from the analysis.

## Before you start

To use this pipeline, you’ll need an [IUCN token](https://api.iucnredlist.org/users/sign_up) to access data on the International Union for Conservation of Nature (IUCN) Red List of Threatened Species.

To interpret the results of this pipeline, it's important to understand the IUCN threat categorizations, which are present throughout the outputs. Some results present these categorizations directly, while others such as the Red List Index (RLI) calculations, use them to model changes in extinction risk over time. The IUCN Red List of Threatened Species defines the following threat categories:

- EX: Exinct
- EW: Extinct in the wild
- RE: Regionally extinct
- CR: Critically endangered
- EN: Endangered
- VU: Vulnerable
- LR/cd: Lower risk - Conservation dependent
- NT or LR/nt: Near threatened
- LC or LR/lc: Least concern
- DD: Data deficient

(IUCN, 2025)

## Running the pipeline


### Pipeline inputs

The BON in a Box RLI pipeline allows you to calculate RLI for species from a country of interest, filtering by taxonomic group, threat type and species use or trade. The inputs to the pipeline are:

- **Country:** The user must choose the country for which they want to calculate RLI.

- **Taxonomic group:** The user can specify the taxonomic group(s) for which they want to calculate RLI using the drop-down menu. This is a multi-select menu. If 'All' is selected, the pipeline will include all taxon groups.

- **Threat category:** The user can specify which species threat(s) to filter the species by. This is a multi-select menu. For example, if the user chooses 'Pollution', the RLI will be calculated only for species threatened by pollution. The user can choose to omit this filter by selecting 'Do not filter by threat category'.

- **Species use:** The user can specify which species use(s) or trade(s) to filter the species by. This is a multi-select menu. For example, if the user chooses 'Medicine - human & veterinary', the RLI will be calculated only for species that are used in the medical industry. The user can choose to omit this filter by selecting 'Do not filter by species use or trade'. If 'All' is selected, the pipeline will include all species that are utilized.

### Pipeline steps

#### **1. Getting a list of species for the country of interest**

This step retrieves the full list of species assessed by the IUCN Red List of Threatened Species for the country of interest including their most recent threat categorization.

#### **2. Getting a list of species for the taxon group(s) selected**

This step retrieves the full list(s) of species assessed by the IUCN Red List of Threatened Species for the taxonomic group(s) selected. If 'All' is selected for Taxonomic group, this step will return an empty list so that there is no filter based on taxonomic group.

#### **3. Getting a list of species threatened by the threat type(s) selected**

This step retrieves the full list(s) of species assessed by the IUCN Red List of Threatened Species that are threatened by the threat type(s) selected. If 'Do not filter by threat category' is selected for Threat category, this step will return an empty list so that there is no filter based of threat type.

#### **4. Getting a list of species for the use(s) or trade(s) selected**

This step retrieves the full list(s) of species assessed by the IUCN Red List of Threatened Species that are involved in the use(s) or trade(s) selected. If 'Do not filter by species use or trade' is selected for Species use, this step will return an empty list so that there is no filter based on use or trade. If 'All' is selected for Species use, this step will return all species involved in a use or trade, also known as *utilized* species.

#### **5. Combining lists from the previous steps into one list**

This step takes the list of species for the country of interest and filters out species that are not found in any of the lists from step 2, 3, and 4.

#### **6. Calculating the percentage of improving species**

This step retrieves the IUCN Red List of species improving in assessment status and finds how many of those species are in the list from the previous step. This number is then divided by the total number of species in the list from the previous step and then multiplied by 100 to find the percentage of species improving in assessment status.

#### **7. Getting the history assessment for the species**

This step returns the history of assessments (year and assessment status) for every species in the list from step 5.

#### **8. Calculating the Red List Index**

This step calculates the Red List Index for the species using their history of assessments. Most species move between categories on the IUCN Red List due to improvements in knowledge or revised taxonomy, so merely looking at the number of species in each category over time is not a meaningful measure of overall changes in extinction risk. RLI was developed to reflect genuine improvement or deterioration in the status of individual species (Butchart et al., 2004; Butchart et al., 2005), and is calculated based on the proportion of species in each category on the Red List (Least Concern, Vulnerable, Endangered, etc.) and weighted by the proportion of the area that is in the country or region of interest. RLI can be calculated for all of the species in a given area, or separately for specific taxa (e.g. birds), or other specified groups (e.g. endemic species). The RLI values range between 0 (indicating all species are extinct) to 1 (indicating all species are Least Concern). For more detailed information on the RLI, visit the [IUCN website](https://www.iucnredlist.org/).

### Pipeline outputs

- **Red List data:** A dataset that describes the results of the RLI calculation.

- **Red List trend plot:** The Red List Index of species for the chosen taxonomy group over time. An RLI of 1 indicates that all species have a status of Least Concerned, while 0 indicates Extinct. If the RLI value is constant over time, the overall extinction risk remains unchanged. An upward trend shows a reduction in the rate of biodiversity loss.

- **Red List matrix:** A matrix of the threat categories of all the species of interest over time.

- **Country:** The country from which the species list was taken.

- **Taxonomic group(s):** The taxonomic group(s) of the species that were assessed.

- **Species threat(s):** The threats the assessed species are under.

- **Species use(s):** The use(s) or trade(s) the assessed species are involved in.

- **IUCN API citation:** Citation for the data acquired using the IUCN Red List API.

## Example

**Sample run:** See an example RLI run here in the [run ui](https://pipelines-results.geobon.org/pipeline-form/RLI_pipeline%3EIUCN_RLI_pipeline/46192f03723b43152495c84ac15175cf) and [viewer](https://pipelines-results.geobon.org/viewer/RLI_pipeline%3EIUCN_RLI_pipeline%3E46192f03723b43152495c84ac15175cf).

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

IUCN. 2025. The IUCN Red List of Threatened Species. Version 2025-1. https://www.iucnredlist.org.


