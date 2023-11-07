#!/bin/bash

# TODO change repo-split for main
branch=repo-split

echo "Updating server init script..."
if cd .server; then
    git fetch origin $branch --depth 1
else 
    git clone -n git@github.com:GEO-BON/bon-in-a-box-pipeline-engine.git --branch $branch --single-branch .server --depth 1
    cd .server;
fi

git checkout origin/$branch -- prod-server-up.sh
./prod-server-up.sh
