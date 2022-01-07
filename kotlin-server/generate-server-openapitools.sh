#!/bin/bash
docker run --rm -v "${PWD}:/local" openapitools/openapi-generator-cli generate \
   -i /local/api/openapi.yaml \
   -g kotlin-server \
   -o /local/
