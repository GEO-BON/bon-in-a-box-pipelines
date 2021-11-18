# syntax=docker/dockerfile:1
## If changes are made to this file, be sure to run "docker compose build" to rebuild it.
## "docker compose up" would not rebuild the image.

## Java installation
#node:17 is build upon buildpack-deps:bullseye, which includes many packages.
FROM node:17 AS with-java
RUN set -ex; \
    apt-get update; \
    apt-get install -y --no-install-recommends openjdk-17-jre; \
    apt-get clean all;
ENV JAVA_HOME /usr/lib/jvm/java-17-openjdk-amd64/
ENV PATH $JAVA_HOME/bin:$PATH

## R installation
FROM with-java AS with-r
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
    apt-get install -y --no-install-recommends r-base \
        libgdal-dev r-cran-devtools r-cran-rcppeigen libudunits2-dev r-cran-rjava; \
    apt-get clean all;\
    Rscript --version


## If there is something missing in the R installation, we can check what is done here for inspiration: 
## https://github.com/rocker-org/rocker/blob/master/r-base/latest/Dockerfile