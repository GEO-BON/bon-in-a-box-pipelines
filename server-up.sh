#!/bin/bash

# Start the BON in a Box microservices locally.
# The UI can then be accessed throught the localhost of this machine.

# Optional arg 1: branch name of server repo, default "main"
branch=${1:-"main"}
shift
# Additionnal optional args will be appended to the docker compose up command.
# Typical use is to give a specific service name to (re)start only that one.
options=$@

function assertSuccess {
    RED="\033[31m"
    ENDCOLOR="\033[0m"
    if [[ $? -ne 0 ]] ; then
        echo -e "${RED}FAILED${ENDCOLOR}" ; exit 1
    fi
}

echo "Updating server init script..."
if cd .server; then
    # Check for a branch change
    remoteFetch="+refs/heads/$branch:refs/remotes/origin/$branch"
    if [[ "$(git config remote.origin.fetch)" != $remoteFetch ]]; then
        echo "Switching to branch $branch..."

        # Change branch restriction of shallow repo.
        # We are not really changing branch but just allowing to checkout individual files from that other branch.
        git config remote.origin.fetch "$remoteFetch"
        # Delete all except .git, . and ..
        ls -a | grep -Ev "^(\.git|\.|\.\.)$" | xargs rm -r
    fi

    git fetch --no-tag --depth 1 origin $branch
    assertSuccess
else
    git clone -n git@github.com:GEO-BON/bon-in-a-box-pipeline-engine.git --branch $branch --single-branch .server --depth 1
    assertSuccess
    cd .server
    assertSuccess
fi

echo "Using branch $branch."
git checkout origin/$branch -- prod-server.sh
assertSuccess

./prod-server.sh checkout $branch
./prod-server.sh up $options
