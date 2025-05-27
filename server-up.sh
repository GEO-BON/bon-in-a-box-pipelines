#!/bin/bash

# Start the BON in a Box microservices locally.
# The UI can then be accessed throught the localhost of this machine.

RED="\033[31m"
ENDCOLOR="\033[0m"
function assertSuccess {
    if [[ $? -ne 0 ]] ; then
        echo -e "${RED}FAILED${ENDCOLOR}" ; exit 1
    fi
}

offline=false
while (( $# > 0 )) ; do
  case $1 in
    -c|--clean) ./.server/prod-server.sh clean ;;
    --offline) offline=true ;;
    -h|--help)
        echo "Usage: ./server-up.sh [OPTIONS] [GIT BRANCH]"
        echo
        echo "Starts the BON in a Box server locally."
        echo "The server will be available at http://localhost."
        echo
        echo "OPTIONS:"
        echo "  -h, --help          Display this help"
        echo "  -c, --clean         Discards the docker containers before starting the server."
        echo "                      Warning: any dependency or conda environment installed at runtime will be lost."
        echo "      --offline       Run the existing version of the server. "
        echo "                      Will not attempt to pull the latest version or the containers nor server configuration."
        echo
        echo "GIT BRANCH:           Refers to the git branch of the server, on https://github.com/GEO-BON/bon-in-a-box-pipeline-engine."
        echo "                      The branch must be available on the docker hub. It is the case for main, edge, and *staging branches."
        echo "                      Default: main"
        echo
        exit 0 ;;
    *) break ;;
  esac

  shift
done

if [ "$offline" = true ]; then
    echo "Running server in offline mode."
    ./.server/prod-server.sh command up -d --no-recreate
    exit 0
fi

# Optional arg: branch name of server repo, default "main"
branch=${1:-"main"}


if [ -L .server ]; then
    echo "Warning: .server is a symlink, will not attempt branch change nor checkout.";
    cd .server;
else
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

    echo "Using git branch $branch."
    git checkout origin/$branch -- prod-server.sh
    assertSuccess

    ./prod-server.sh checkout $branch

fi

./prod-server.sh up
