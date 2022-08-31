#!bin/sh
docker-compose -f /scripts/pyLoadObservations/docker/docker-compose.yaml run pc-dock python -u /home/jovyan/scripts/pyLoadObservations/getocc/get_occ.py ${1}