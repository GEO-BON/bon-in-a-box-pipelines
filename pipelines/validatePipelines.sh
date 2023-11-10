#!/bin/sh

# Windows users: using powershell, type "bash" command to enter bash, then run this script.
# See https://stackoverflow.com/a/44359679/3519951

../.server/.github/findDuplicateIds.sh

# Server not running TODO: not working...
#docker run geobon/bon-in-a-box:script-server java -cp biab-script-server.jar org.geobon.pipeline.Validator
# When server running:
docker exec -it biab-script-server java -cp biab-script-server.jar org.geobon.pipeline.Validator