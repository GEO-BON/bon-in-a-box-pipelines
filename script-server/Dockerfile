## If changes are made to this file, be sure to run "docker compose build" to rebuild it.
## "docker compose up" would not rebuild the image.


FROM node:17 #node:17 is build upon buildpack-deps:bullseye, which includes many packages.

RUN set -ex; \
    apt-get update && apt-get install -y lsb-release software-properties-common apt-utils; \
    # R ppa setup to have the latest version (otherwise it's a year behing) \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-key 'E19F5F87128899B192B1A2C2AD5F960A256A04AF'; \
    add-apt-repository "deb https://cloud.r-project.org/bin/linux/debian $(lsb_release -cs)-cran40/"; \
    apt-get update; \
    apt-get install -y --no-install-recommends r-base; \
    apt-get clean all; \
    Rscript --version


## If there is something missing in the R installation, we can check what is done here for inspiration: 
## https://github.com/rocker-org/rocker/blob/master/r-base/latest/Dockerfile