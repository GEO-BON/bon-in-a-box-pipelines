#!/bin/bash

RED="\033[31m"
ENDCOLOR="\033[0m"

echo "Checking for duplicate lines inside each yml files..."
# This is a frequent error in step YML files when adding an additionnal param : 
# Copy paste the param above and forget to change the description!

# Checking inside the same file only : 
# some description duplication will occur naturally between files and it's OK.
# ex. "Species name" description should always look the same!

RESULTS=$(find . -name "*.yml" -exec sh -c "echo {}; \
grep \"description:
text:
doi:\" '{}' \
  | sort \
  | uniq -d \
  | awk '{print \"${RED}\" \"[DUPLICATE] \" \$0 \"${ENDCOLOR}\"}'" \;)

echo "$RESULTS"

if [[ "$RESULTS" == *"[DUPLICATE]"* ]]
  then exit 1
fi