## If changes are made to this file, be sure to run "docker compose build" to rebuild it.
## "docker compose up" would not rebuild the image.

#FYI, node:17 is build upon buildpack-deps:bullseye, which includes many packages.
FROM node:17

RUN set -ex; \
    apt-get update; \
    apt-get install -y --no-install-recommends r-base; \
    rm -rf /var/lib/apt/lists/*; \
    Rscript --version


## If there is something missing in the R installation, we can check what is done here for inspiration: 
## https://github.com/rocker-org/rocker/blob/master/r-base/latest/Dockerfile