#!/bin/bash

wget --no-clobber https://repo1.maven.org/maven2/io/swagger/codegen/v3/swagger-codegen-cli/3.0.30/swagger-codegen-cli-3.0.30.jar \
    --directory-prefix=./api/

java -jar ./api/swagger-codegen-cli-3.0.30.jar generate -i ./api/openapi.yaml -l nodejs-server