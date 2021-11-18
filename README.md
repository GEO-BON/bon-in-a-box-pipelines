# BON in a Box 2.0

Mapping Post-2020 Global Biodiversity Framework indicators and their uncertainty.

A Geo BON project, born from a collaboration between Microsoft, McGill, Humbolt institue, Université de Sherbrooke, Université Concordia and Université de Montréal.

Prerequisites : 
 - Linux: Docker with docker compose installed
 - Windows/Mac: Docker Desktop

To run:
1. Clone repository
2. Navigate to top-level folder
3. docker compose build (this needs to be re-run every time a Dockerfile is modified)
4. docker compose up
5. In browser:
    - http://localhost:8081/script/HelloWorld.R should run an R script.
    - http://localhost:8081/script/blabla should return "not found" error message.
    - http://localhost:8081/docs shows the API documentation
