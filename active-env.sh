#!/bin/bash

scr_dir="${0%/*}"
envs_dir="$scr_dir/environments"
running=''
runcnt=0

for dir in "$envs_dir"/*/
do
   mname=$(basename "$dir")
   if docker ps -f "label=com.docker.compose.project=$mname" --format '{{.Names}}' | grep -q moodle; then
      (( runcnt++ )) || true
      running="$mname"
   fi
done

[ $runcnt -eq 1 ] && echo "$running" || echo ''
