#!/bin/bash
set -ex
cp ../../script-server/api/openapi.yaml .

docker pull openapitools/openapi-generator-cli
docker run --rm -v "${PWD}:/local" openapitools/openapi-generator-cli generate \
   -i /local/openapi.yaml \
   -g javascript \
   -o /local/

rm openapi.yaml