#!bin/sh
docker-compose -f /scripts/data/pyLoadObservations/docker/docker-compose.yaml build
docker-compose -f /scripts/data/pyLoadObservations/docker/docker-compose.yaml run pc-dock python -u /home/jovyan/scripts/data/pyLoadObservations/getocc/get_occ.py ${1}
#test254