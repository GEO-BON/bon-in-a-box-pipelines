#!/bin/bash
echo '{\n"a_number": 234\n}' | tee "$1/output.json"

# Note: using tee, since with the following command sometimes the file is created with a delay.
# echo '{\n"a_number": 234\n}' > "$1/output.json"