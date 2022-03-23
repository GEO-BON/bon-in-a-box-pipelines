#!bin/sh
cd /scripts/pyLoadObservations/docker/
docker-compose run pc-dock python /home/jovyan/scripts/pyLoadObservations/getocc/get_occ.py ${1}