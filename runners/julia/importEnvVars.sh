#!/bin/bash

## Bash initialisation
# Load runner.env
while IFS== read -r key value; do
    # Ignore comments and empty lines
    [[ -z "$key" || "$key" =~ ^# ]] && continue
    # Export
    printf -v "$key" %s "$value" && export "$key"
done </runner.env