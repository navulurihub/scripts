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

dir=$PWD
echo $PWD
echo "reading files from directory $dir"

#refresh the output file before the execution
rm -rf final_file.csv

cat <<EOT >> pattern.txt
GITHUB SOURCE ORG
SOURCE REPO
GITHUB TARGET ORG
TARGET REPO
TARGET REPO VISIBILITY
Migration completed
\[ERROR
EOT

#create heading line in final csv file
echo "STARTTIME,ENDTIME,DIFF IN MINs,SOURCE ORG, SOURCE REPO, TARGET ORG, TARGET REPO, REPO VISIBILITY, REMARKS" > final_file.csv

for file in "$dir"/*.verbose.log 
do 
    filename=$(basename $file)
    echo "$filename"
    cat $file | grep "^\[" > temp_file1          # get only records which starts with "["
    sed -e 1b -e '$!d' temp_file1 > temp_file2   # get first and last lines of the file for start and end time
    grep -f pattern.txt temp_file1 >> temp_file2 # extract records which matches the pattern.txt
    nl -w1 -s' ' temp_file2 > temp_file3         # add numbers to the starting of the line
    
    final_line=''
    while read line; do
        if [[ ${line:0:1} == 1 || ${line:0:1} == 2 ]] ; then
            var1=`echo $line | cut -c 15-22`
            final_line+=$var1,
            if [[ ${line:0:1} == 2 ]]; then
                old=`echo $final_line | cut -f1 -d ','`
                new=`echo $final_line | cut -f2 -d ','`
                # feeding variables by using read and splitting with IFS
                IFS=: read old_hour old_min old_sec <<< "$old"
                IFS=: read hour min sec <<< "$new"
                total_old_minutes=$((10#$old_hour*60 + 10#$old_min))
                total_minutes=$((10#$hour*60 + 10#$min))
                diff=$((total_minutes - total_old_minutes))
                final_line+=$diff,
            fi
        else
            var1=`echo $line | cut -f3 -d']'`
            final_line+=$var1,
        fi
    done < temp_file3
    final_line+=$filename
    echo $final_line >> final_file.csv
done 

rm -rf temp_file1 temp_file2 temp_file3 pattern.txt