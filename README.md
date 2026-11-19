# BON in a Box Pipelines

**Open-source workflows for biodiversity monitoring, analysis, and indicator calculation.**

## Overview

[BON in a Box](https://boninabox.geobon.org/) is an open-source platform developed by [GEO BON](https://geobon.org/) to support biodiversity monitoring, indicator calculation, and reporting. It provides tools to help researchers, practitioners, and decision-makers access biodiversity data, conduct analyses, and generate information relevant to biodiversity assessment and conservation planning, including the Kunming-Montreal Global Biodiversity Framework (KMGBF).

This repository contains the **biodiversity analysis pipelines** used by the BON in a Box Biodiversity Evaluation Engine (BEE).

A *pipeline* is a reproducible computational workflow that transforms input data into biodiversity indicators, Essential Biodiversity Variables (EBVs), or other analysis outputs. Pipelines combine individual processing and analysis steps, allowing users to apply established methods to different geographic areas, datasets, and research questions.

Pipelines are open-source and designed to be transparent, reproducible, and adaptable to local contexts.

## Explore available pipelines

BON in a Box includes pipelines for calculating biodiversity indicators and EBVs, as well as other analyses to support biodiversity monitoring and assessment.

Each pipeline brings together a series of computational steps, from accessing and processing input data to performing analyses and generating results. Depending on the workflow, users can select their geographic area, adjust parameters, and incorporate publicly available or user-provided datasets.

**[Browse available pipelines](https://boninabox.geobon.org/browse-pipelines)** to explore the analyses currently available through BON in a Box.

## Running pipelines

Pipelines can be run through the **Biodiversity Evaluation Engine (BEE)**, which provides a user interface for configuring, executing, and exploring biodiversity analyses without needing to run the underlying code manually.

The general workflow is:

1. **Choose a pipeline** for the indicator, EBV, or analysis of interest.
2. **Configure the analysis** by selecting a study area, setting parameters, and choosing publicly available or user-provided datasets.
3. **Run the pipeline** and explore or download the resulting outputs.

BEE can be accessed through:

- **[Online BEE platform](https://boninabox.geobon.org/get-started-with-bee)** — Access the online beta version.
- **[User documentation](https://geo-bon.github.io/bon-in-a-box-pipeline-engine/)** — Instructions for running pipelines, using the interface, and installing BEE locally.

## Contributing pipelines

BON in a Box is a collaborative project, and contributions are welcome.

Users can contribute new pipelines, adapt existing workflows, or improve individual scripts. Contributions should follow the project's pipeline standards and undergo testing and peer review.

For more information:

- **[Contributing guidelines](https://geo-bon.github.io/bon-in-a-box-pipeline-engine/how_to_contribute.html)** — How to develop and submit pipelines or scripts.
- **[Pipeline standards](https://geo-bon.github.io/bon-in-a-box-pipeline-engine/pipeline_standards.html)** — Requirements for pipeline structure, documentation, and reproducibility.
- **[Peer review process](https://geo-bon.github.io/bon-in-a-box-pipeline-engine/peer_review.html)** — How pipelines are reviewed before publication.

Contributions can be proposed through a GitHub pull request.

## Repository structure

This repository contains the pipeline metadata, scripts, and execution environments used by BEE.

- [`pipelines/`](https://github.com/GEO-BON/bon-in-a-box-pipelines/tree/main/pipelines) — Pipeline metadata specifying the sequence of analysis steps, inputs, and outputs.
- [`scripts/`](https://github.com/GEO-BON/bon-in-a-box-pipelines/tree/main/scripts) — Individual computational scripts used within pipelines.
- [`runners/`](https://github.com/GEO-BON/bon-in-a-box-pipelines/tree/main/runners) — Execution environments and dependencies used to run scripts.

The software infrastructure and user interface for BEE are maintained separately in the [BON in a Box Pipeline Engine repository](https://github.com/GEO-BON/bon-in-a-box-pipeline-engine).

## Additional resources

- [BON in a Box website](https://boninabox.geobon.org/) — Learn about the broader platform, including the Tools Portal, Projects Portal, and BEE.
- [User documentation](https://geo-bon.github.io/bon-in-a-box-pipeline-engine/) — Detailed guides for using, installing, and contributing to BEE.
- [Developer documentation](https://github.com/GEO-BON/bon-in-a-box-pipeline-engine/blob/main/README-dev.md) — Technical documentation for developing BEE's server infrastructure and user interface.
- [BON in a Box 2023](https://youtu.be/mLjnjCWwU3w?si=Zdj_HmMSh3SH5BpE) — Video introduction to BON in a Box.
- [What's in the box?](https://youtu.be/QJ1j455Tsuo?si=5C-kJ63vlcFfXtca) — Video overview of BON in a Box.
- [BON in a Box webinar](https://youtu.be/6QHSX1Y70ss) — A longer introduction to the platform.

## Citation

If you use BON in a Box in your research or applications, please cite:

> Jory Griffith, Jean-Michel Lord, Michael D Catchen, Maria Isabel Arce-Plata,
> F Guillaume Blanchet, Mathusan Chandramohan, M Camila Diaz-Corzo, Dominique
> Gravel, César Gutiérrez, Isabelle S Helfenstein, Sean Hoban, Jamie M Kass,
> Linda Laikre, Guillaume Larocque, Deborah M Leigh, Brian Leung, Alicia
> Mastretta-Yanes, Katie L Millette, Maria Alejandra Molina Berbeo, Dat Nguyen,
> Kari E Norman, María Helena Olaya-Rodríguez, Simon Pahls, Kaitlyn Pereira, Pedro
> R Peres-Neto, Timothée Poisot, Laura J Pollock, Juan Carlos Rey-Velasco, Victor
> J Rincon-Parra, Claudia Roeoesli, François Rousseu, Lina María Sánchez-Clavijo,
> Meredith C Schuman, Oliver Selmoni, Jessica M da Silva, Erika Suarez-Valencia,
> Thilina D Surasinghe, Eren Turak, Luis Fernando Urbina, Sarah Valentin, Noah
> Wightman, Juan Zuloaga, Maria Cecilia Londoño, Andrew Gonzalez. 2026. BON in a
> Box: An Open and Collaborative Platform for Biodiversity Monitoring, Indicator
> Calculation, and Reporting. *BioScience*. 76(4):345–358.
> https://doi.org/10.1093/biosci/biaf189

Where available, please also cite the specific pipelines, methods, and datasets used in your analysis.

____________________


*A GEO BON project, born from a collaboration between McGill University, the Humboldt Institute, Université de Sherbrooke, Concordia University, and Université de Montréal, with seed funding from Microsoft.*