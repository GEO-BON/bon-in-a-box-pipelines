#!/bin/bash

echo "Updating server init script..."
if cd .server; then
    git fetch
else 
    git clone -n git@github.com:GEO-BON/bon-in-a-box-pipeline-engine.git .server --depth 1
    cd .server;
fi

# TODO change repo-split for main
git checkout origin/repo-split -- prod-server-up.sh
./prod-server-up.sh
