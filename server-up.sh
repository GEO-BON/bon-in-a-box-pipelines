#!/bin/bash

# Start the BON in a Box microservices locally.
# The UI can then be accessed throught the localhost of this machine.

RED="\033[31m"
YELLOW="\033[33m"
ENDCOLOR="\033[0m"
function assertSuccess {
    if [[ $? -ne 0 ]] ; then
        echo -e "${RED}FAILED${ENDCOLOR}" ; exit 1
    fi
}

offline=false
startServer=true
skipPrompts=""
while (( $# > 0 )) ; do
  case $1 in
    -c|--clean) ./.server/prod-server.sh clean ;;
    -y|--yes) skipPrompts="-y" ;;
    --offline) offline=true ;;
    -v|--version)
        cd .server
        ./prod-server.sh version
        exit 0 ;;
    --initialize)
        startServer=false
        ;;
    --licence|--license)
        ./.server/prod-server.sh licence
        exit 0 ;;
    -h|--help)
        echo "Usage: ./server-up.sh [OPTIONS] [GIT BRANCH/TAG]"
        echo
        echo "Starts the BON in a Box server locally."
        echo "The server will be available at http://localhost"
        echo
        echo "OPTIONS:"
        echo "  -h, --help          Display this help"
        echo "  -c, --clean         Discard the docker containers before starting the server."
        echo "                      Warning: any dependency or conda environment installed at runtime will be lost."
        echo "  -y, --yes           Skip update confirmation prompt (for automation)"
        echo "      --offline       Run the currently installed version of the server. "
        echo "                      Will not attempt to pull the latest version or the containers nor server configuration."
        echo "  -v, --version       Display version information"
        echo "      --initialize    Initialize the server configuration. This will create a .server folder with the server"
        echo "                      configuration files, but will not start the server."
        echo "                      When --offline flag is used, this option will be ignored."
        echo "      --licence       Display licence information"
        echo
        echo "GIT BRANCH/TAG:       Refers to the git branch or tag of the server, on https://github.com/GEO-BON/bon-in-a-box-pipeline-engine"
        echo "                      The branch must be available on the GitHub package registry, such as main, edge, and *staging branches."
        echo "                      Tags are detected automatically. Default branch: main"
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

# Optional positional arg: branch name or tag of server repo, default "main"
gitRef=${1:-"main"}

# Auto-detect whether the argument is a branch or a tag
remoteUrl="git@github.com:GEO-BON/bon-in-a-box-pipeline-engine.git"
if git ls-remote --exit-code --heads "$remoteUrl" "$gitRef" > /dev/null 2>&1; then
    isTag=false
    refType="branch"
elif git ls-remote --exit-code --tags "$remoteUrl" "$gitRef" > /dev/null 2>&1; then
    isTag=true
    refType="tag"
else
    echo -e "${RED}Error: '$gitRef' is neither a branch nor a tag on the remote repository.${ENDCOLOR}"
    exit 1
fi

if [ -L .server ]; then
    echo "Warning: .server is a symlink, will not attempt branch change nor checkout.";
    cd .server;
else
    echo "Updating server init script..."
    if cd .server; then
        # Check for a branch/tag change
        if [ "$isTag" = true ]; then
            remoteFetch="+refs/tags/$gitRef:refs/tags/$gitRef"
        else
            remoteFetch="+refs/heads/$gitRef:refs/remotes/origin/$gitRef"
        fi

        if [[ "$(git config remote.origin.fetch)" != $remoteFetch ]]; then
            echo "Switching to $refType $gitRef..."

            # Change branch restriction of shallow repo.
            # We are not really changing branch but just allowing to checkout individual files from that other branch.
            git config remote.origin.fetch "$remoteFetch"
            # Delete all except .git, . and ..
            ls -a | grep -Ev "^(\.git|\.|\.\.)$" | xargs rm -r
        fi

        if [ "$isTag" = true ]; then
            git fetch --depth 1 origin refs/tags/$gitRef ; assertSuccess
        else
            git fetch --no-tag --depth 1 origin $gitRef ; assertSuccess
        fi

    else
        git clone -n git@github.com:GEO-BON/bon-in-a-box-pipeline-engine.git --branch $gitRef --single-branch .server --depth 1
        assertSuccess
        cd .server
        assertSuccess
    fi

    echo "Using git $refType $gitRef."
    if [ "$isTag" = true ]; then
        git checkout refs/tags/$gitRef -- prod-server.sh
    else
        git checkout origin/$gitRef -- prod-server.sh
    fi
    assertSuccess

    ./prod-server.sh checkout $gitRef
    if [[ $? -ne 0 ]] ; then
        echo -e "${YELLOW}Failed to checkout server configuration files from $refType $gitRef."
        echo -e "${YELLOW}Please check that the branch or tag exists and contains the necessary configuration files.${ENDCOLOR}"
        echo -e "${YELLOW}You may also try to run './server-up.sh --offline' to run the currently installed version of the server.${ENDCOLOR}"
        exit 1;
    fi
fi

if [ "$startServer" = true ]; then
    ./prod-server.sh up $skipPrompts
fi
