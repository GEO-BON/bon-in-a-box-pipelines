#!/bin/bash

RED="\033[31m"
ENDCOLOR="\033[0m"

echo "Checking for duplicate lines inside each yml files..."
# A duplicate id in a pipeline JSON file can occur after a merge that went wrong.
# The usual solution is to delete one of the two edges, but it needs careful manual validation
# to check if the edges connected the same steps.

RESULTS=$(find . -name "*.json" -exec sh -c "echo {}; \
grep \"\\\"id\\\": \\\"\" '{}' \
  | sort \
  | uniq -d \
  | awk '{print \"${RED}\" \"[DUPLICATE] \" \$0 \"${ENDCOLOR}\"}'" \;)

echo "$RESULTS"

if [[ "$RESULTS" == *"[DUPLICATE]"* ]]
  then exit 1
fi