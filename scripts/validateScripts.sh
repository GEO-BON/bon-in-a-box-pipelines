#!/bin/sh
docker run -v $(pwd):"/scripts" navikt/yaml-validator:v4 "scripts/cerberusValidationSchema" "scripts/" "no" ".yml"