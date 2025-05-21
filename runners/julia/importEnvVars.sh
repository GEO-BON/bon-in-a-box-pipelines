#!/bin/sh

## Bash initialisation
# Load runner.env
while IFS== read -r key value; do
    case "$key" in
        ''|\#*) continue ;;
    esac
    export "$key=$value"
done < runner.env