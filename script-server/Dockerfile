## If changes are made to this file, be sure to run "docker compose build" to rebuild it.
## "docker compose up" would not rebuild the image.

#node:17 is build upon buildpack-deps:bullseye, which includes many packages.
FROM node:17 

## Add user to 'staff' group, granting them write privileges to /usr/local/lib/R/site.library
RUN addgroup node staff

## R prerequisites
RUN set -ex; \
    apt-get update && apt-get install -y lsb-release software-properties-common apt-utils;  \
    # R ppa setup to have the latest version (otherwise it's a year behing) \
    # apt-key adv --keyserver keyserver.ubuntu.com --recv-key 'E19F5F87128899B192B1A2C2AD5F960A256A04AF'; \
    add-apt-repository "deb https://cloud.r-project.org/bin/linux/debian $(lsb_release -cs)-cran40/"; \
    \
## TEMP FIX for signature issue https://stackoverflow.com/a/69977747/3519951 \
    sed -i 's/deb https:\/\/cloud.r-project.org\/bin\/linux\/debian bullseye-cran40\//deb [trusted=yes] https:\/\/cloud.r-project.org\/bin\/linux\/debian bullseye-cran40\//g' /etc/apt/sources.list; \
    cat /etc/apt/sources.list; \
    \
## R installation \
    apt-get update; \
    apt-get install -y --no-install-recommends r-base; \
    apt-get clean all; \
    Rscript --version


## If there is something missing in the R installation, we can check what is done here for inspiration: 
## https://github.com/rocker-org/rocker/blob/master/r-base/latest/Dockerfile