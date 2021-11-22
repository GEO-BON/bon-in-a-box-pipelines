# syntax=docker/dockerfile:1

## If changes are made to this file, be sure to run "docker compose build" to rebuild it.
## "docker compose up" would not rebuild the image.

## R installation
#node:17 is build upon buildpack-deps:bullseye, which includes many packages.
FROM node:17 AS with-r-base
RUN set -ex; \
    apt-get update; \
    # R prerequisites, including GFortran to compile some packages
    apt-get install -y lsb-release software-properties-common apt-utils gfortran;  \
    # R ppa setup to have the latest version (otherwise it's a year behing) \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-key '95C0FAF38DB3CCAD0C080A7BDC78B2DDEABC47B7'; \
    add-apt-repository "deb https://cloud.r-project.org/bin/linux/debian $(lsb_release -cs)-cran40/"; \
    apt-get update; \
    \
    # TEMP FIX for signature issue https://stackoverflow.com/a/69977747/3519951 \
    #sed -i 's/deb https:\/\/cloud.r-project.org\/bin\/linux\/debian bullseye-cran40\//deb [trusted=yes] https:\/\/cloud.r-project.org\/bin\/linux\/debian bullseye-cran40\//g' /etc/apt/sources.list; \
    #cat /etc/apt/sources.list; \
    \
    # R installation \
    apt-get install -y --no-install-recommends r-base; \
    Rscript --version; \
    apt-get clean all;

FROM with-r-base AS with-r-libs
RUN set -ex; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        libgdal-dev \
        libudunits2-dev \
        r-cran-devtools \
        r-cran-rcppeigen \
        r-cran-rjava; \
    apt-get clean all;


# TODO#20: Install Python

## Java installation (currently replaced by using r-cran-rjava)
#FROM node:17 AS with-java
# AS with-java
# RUN set -ex; \
#     apt-get update; \
#     apt-get install -y --no-install-recommends openjdk-17-jre; \
#     apt-get clean all; \
#     R CMD javareconf;
# ENV JAVA_HOME /usr/lib/jvm/java-17-openjdk-amd64/
# ENV PATH $JAVA_HOME/bin:$PATH

## If there is something missing in the R installation, we can check what is done here for inspiration: 
## https://github.com/rocker-org/rocker/blob/master/r-base/latest/Dockerfile