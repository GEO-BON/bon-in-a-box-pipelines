#!/bin/bash

# Start the BON in a Box microservices locally.
# The UI can then be accessed throught the localhost of this machine.

# Optional arg 1: branch name of server repo, default "main"
branch=${1:-"main"}

echo "Updating server init script..."
if cd .server; then
    # Check for a branch change
    if [[ "$(git branch --show-current)" != $branch ]]; then
        echo "Switching to branch $branch..."

        # Change branch restriction of shallow repo.
        # We are not really changing branch but just allowing to checkout individual files from that other branch.
        git config remote.origin.fetch "+refs/heads/$branch:refs/remotes/origin/$branch"
        # Delete all except .git, . and ..
        ls -a | grep -Ev "^(\.git|\.|\.\.)$" | xargs rm -r
    fi

    git fetch --no-tag --depth 1 origin $branch 
else 
    git clone -n git@github.com:GEO-BON/bon-in-a-box-pipeline-engine.git --branch $branch --single-branch .server --depth 1
    cd .server;
fi

echo "Using branch $branch."
git checkout origin/$branch -- prod-server-up.sh
./prod-server-up.sh $branch
