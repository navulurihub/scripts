#################################################################################################################
# This script helps to perform following operations
# 1. Read each log file from the specified folder
# 2. get only records which starts with "["
# 3. get first and last lines of the file for start and end time
# 4. extract records which matches the pattern.txt
# 5. add numbers to the starting of the line
# 6. Calculating the migration duration using time difference 
# 7. Generate single file with all the required information
####################################################################################################################


#!/bin/bash

rm -rf body.txt

# cat <<EOT >> body.txt
# test1
# test2
# test3
# EOT

repo="test1\ntest2\ntest3"

set +e
for line in $repo; do
    ca
    #echo "$line"
done
echo $?
set -e
