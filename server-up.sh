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
skipPrompts=""
while (( $# > 0 )) ; do
  case $1 in
    -c|--clean) ./.server/prod-server.sh clean ;;
    -y|--yes) skipPrompts="-y" ;;
    --offline) offline=true ;;
    -v|--version)
        if cd .server 2>/dev/null; then
            ./prod-server.sh version
            exit $? 
        else
            echo "Run BON in a Box at least once to get the server version."
            exit 1
        fi
        ;;
    --licence|--license)
        if cd .server 2>/dev/null; then
            ./prod-server.sh licence
            exit $? 
        else
            echo "Run BON in a Box at least once to read its licence."
            exit 1
        fi
        ;;
        
    -h|--help)
        echo "Usage: ./server-up.sh [OPTIONS] [GIT BRANCH]"
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
        echo "  --licence           Display licence information"
        echo
        echo "GIT BRANCH:           Refers to the git branch of the server, on https://github.com/GEO-BON/bon-in-a-box-pipeline-engine"
        echo "                      The branch must be available on the GitHub package registry, such as main, edge, and *staging branches."
        echo "                      Default: main"
        echo
        exit 0 ;;
    *) break ;;
  esac

  shift
done

# .gitattributes enforces LF, but a checkout done while core.autocrlf=true can still have CRLF on disk.
if [[ "$(git config --get core.autocrlf)" == "true" ]]; then
    if [[ -z "$(git status --porcelain)" ]]; then
        echo "Fixing Windows line endings left over from core.autocrlf=true..."
        git config core.autocrlf false
        git rm --cached -r . > /dev/null
        git reset --hard
        assertSuccess
    else
        echo -e "${RED}Warning: core.autocrlf is enabled and this repo has uncommitted changes.${ENDCOLOR}"
        echo "Scripts may contain Windows line endings (\r) that fail inside the Linux Docker containers."
        echo "Commit or stash your changes, then run this script again, or fix it manually with:"
        echo "  git config core.autocrlf false && git rm --cached -r . && git reset --hard"
    fi
fi

if [ "$offline" = true ]; then
    echo "Running server in offline mode."
    ./.server/prod-server.sh command up -d --no-recreate
    exit $?
fi

# Optional arg: branch name of server repo, default "main"
branch=${1:-"main"}


if [ -L .server ]; then
    echo "Warning: .server is a symlink, will not attempt branch change nor checkout.";
    cd .server;
else
    echo "Updating server init script..."
    if cd .server 2>/dev/null; then
        # Check for a branch change
        remoteFetch="+refs/heads/$branch:refs/remotes/origin/$branch"
        if [[ "$(git config remote.origin.fetch)" != $remoteFetch ]]; then
            echo "Switching to branch $branch..."

            # Change branch restriction of shallow repo.
            # We are not really changing branch but just allowing to checkout individual files from that other branch.
            git config remote.origin.fetch "$remoteFetch"
            # Delete all except .git, . and ..
            find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
        fi

        git fetch --no-tag --depth 1 origin "$branch"
        assertSuccess

    else # Fresh install
        
        git clone --no-checkout git@github.com:GEO-BON/bon-in-a-box-pipeline-engine.git \
            --branch "$branch" --single-branch .server --depth 1 \
            --config core.autocrlf=false # ensures scripts checked out keep LF for the Linux docker containers to read
        assertSuccess

        cd .server
        assertSuccess
    fi

    echo "Using git branch $branch."
    git checkout "origin/$branch" -- prod-server.sh
    assertSuccess

    ./prod-server.sh checkout "$branch"

fi

./prod-server.sh up $skipPrompts
