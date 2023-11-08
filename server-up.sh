#!/bin/bash

# Start the BON in a Box microservices locally.
# The UI can then be accessed throught the localhost of this machine.

branch=main

echo "Updating server init script..."
if cd .server; then
    git fetch origin $branch --depth 1
else 
    git clone -n git@github.com:GEO-BON/bon-in-a-box-pipeline-engine.git --branch $branch --single-branch .server --depth 1
    cd .server;
fi

git checkout origin/$branch -- prod-server-up.sh
./prod-server-up.sh
