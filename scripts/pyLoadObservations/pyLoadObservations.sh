#!bin/sh
cd /scripts/pyLoadObservations/docker/
docker-compose -f docker-compose.yaml run pc-dock  python -u /home/jovyan/scripts/pyLoadObservations/getocc/get_occ.py ${1}