# BON in a Box 2.0

Mapping Post-2020 Global Biodiversity Framework indicators and their uncertainty.

A Geo BON project, born from a collaboration between Microsoft, McGill, Humbolt institue, Université de Sherbrooke, Université Concordia and Université de Montréal.

Prerequisites : 
 - Git
 - Linux: Docker with Docker Compose installed
 - Windows/Mac: Docker Desktop
 - At least 6 GB of free space (this includes the installation of Docker Desktop)

To run:
1. Clone repository
2. Navigate to top-level folder
3. docker compose build (this needs to be re-run everytime the server code changes, or when using git pull if you are not certain.)
4. docker compose up -d
5. In browser:
    - http://localhost/ shows a basic UI
    - http://localhost/script/HelloWorld.R runs the specified R script.
    - http://localhost:8081/docs shows the script server's API documentation
6. docker compose down
