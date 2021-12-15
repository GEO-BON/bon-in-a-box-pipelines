#!/bin/bash
set -ex
cp ../../script-server/api/openapi.yaml .

docker run --rm -v "${PWD}:/local" openapitools/openapi-generator-cli generate \
   -i /local/openapi.yaml \
   -g javascript \
   -o /local/

rm openapi.yaml