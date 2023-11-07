#!/bin/bash

# Windows users: using powershell, type "bash" command to enter bash, then run this script.
# See https://stackoverflow.com/a/44359679/3519951

# Find duplicate descriptions
../.server/.github/findDuplicateDescriptions.sh

if [[ $? -ne 0 ]] ; then
    echo "Failed: see error above."
    exit 1
fi

# Validate against schema
docker run -v $(pwd):"/scripts" \
    -v $(pwd)/../.server/.github/:"/.github" \
    navikt/yaml-validator:v4 \
    ".github/scriptValidationSchema.yml" "scripts/" "no" ".yml"
