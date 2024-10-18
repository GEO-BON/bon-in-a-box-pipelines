The Red List Index (RLI) shows trends in overall extinction risk for species, and is used to track progress towards reducing extinctions and biodiversity loss. RLI has been widely integrated into various policy frameworks. Initially used to assess progress towards the Convention on Biological Diversity’s 2010 target (Rodrigues, 2006), it has since been employed in regional, thematic, and global assessments by bodies such as the Intergovernmental Science-Policy Platform on Biodiversity and Ecosystem Services, the Global Environment Outlook, and others (Global Biodiversity Outlook, 2010). The RLI is a key indicator for the UN Sustainable Development Goals, particularly Goal 15, and is adopted by the Convention on Migratory Species and its agreements. It also serves as a headline indicator for Goal A and Target 4 of the CBD’s Kunming-Montreal Global Biodiversity Framework (CBD, 2022). Beyond global trends, the RLI can be used to track trends in species across different biogeographic realms, political units, ecosystems, habitats, taxonomic groups, and those relevant to various international agreements and treaties (Butchart et al., 2004; Butchart et al., 2005).

**Methods:**
Most species move between categories on the IUCN Red List due to improvements in knowledge or revised taxonomy, so merely looking at the number of species in each category over time is not a meaningful measure of overall changes in extinction risk. RLI was developed to reflect genuine improvement or deterioration in the status of individual species (Butchart et al., 2004; Butchart et al., 2005), and is calculated based on the proportion of species in each category on the Red List (Least Concern, Vulnerable, Endangered, etc.) and weighted by the proportion of the area that is in the country or region of interest. RLI can be calculated for all of the species in a given area, or separately for specific taxa (e.g. birds), or other specified groups (e.g. endemic species). The RLI values range between 0 (indicating all species are extinct) to 1 (indicating all species are Least Concern). For more detailed information on the RLI, visit the [IUCN website](https://www.iucnredlist.org/).

**BON in a Box pipeline:**
The BON in a Box RLI pipeline allows you to calculate RLI for specific taxon or species groups and a country of interest. The inputs to the pipeline are:
* **IUCN token:** You must request a token to the IUCN for the script to work
* **Taxon or species group name:** The user can specify the species group for which they want to calculate RLI. This can be taxonomic groups (birds, mammals, amphibians, etc.) or groups of species (endemic species, pollinators, etc.)
* **Country:** The user can specify the country for which you want to calculate RLI

The pipeline creates the following outputs:
* **Red list result:** Table of red list results for each year. This can be downloaded as a CSV.
* **Red list plot:** Displays the change in the Red List Index over years.

See an example RLI output here (coming soon):

**Contributors:**
The function for calculate the RLI, was made by Maria Camila Diaz (mdiaz@humboldt.org.co) and Victor Julio Rincón (vrincon@humboldt.org.co), researchers of Instituto de Investigación de Recursos Biológicos Alexander von Humboldt. The documentation of the script to generate the RLI was built by Maria Camila Diaz in July 2024.

**Citations:**
Butchart SHM, Stattersfield AJ, Bennun LA, Shutes SM, Akçakaya HR, et al. 2004. Measuring global trends in the status of biodiversity: Red List Indices for birds. PLoS Biology 2: e383.

Butchart SHM, Stattersfield AJ, Baillie JEM, Bennun LA, Stuart SN, et al. 2005. Using Red List Indices to measure progress towards the 2010 target andbeyond. Philosophical Transactions of the Royal Society of London B 360: 255–268.

Butchart SH, Resit Akçakaya H, Chanson J, Baillie JE, Collen B, et al. 2007. Improvements to the Red List Index. PLOS ONE 2(1): e140.
Cardoso, P., Branco, V. 2023. IUCN Redlisting Tools (Package red).

CBD 2022. Proposed monitoring framework for the post-2020 global biodiversity framework. CBD: Convention on Biological Diversity.
Global Biodiversity Outlook. 2010. Global biodiversity outlook 3. In Montréal, Canada: Secretariat of the Convention on Biological Diversity.(http://gbo3. cbd. int/) Phil. Trans. R. Soc. B (Vol. 9).
Rodrigues ASL, Pilgrim JD, Lamoreux JF, Hoffmann M, Brooks TM.2006. The value of the IUCN Red List for Conservation. Trends in Ecology & Evolution 21: 71–76.
