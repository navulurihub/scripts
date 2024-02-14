#!/bin/bash
old=09:11:13
new=17:22:15

# feeding variables by using read and splitting with IFS
IFS=: read old_hour old_min old_sec <<< "$old"
IFS=: read hour min sec <<< "$new"

total_old_minutes=$((10#$old_hour*60 + 10#$old_min))
total_minutes=$((10#$hour*60 + 10#$min))

echo "the difference is $((total_minutes - total_old_minutes)) minutes"