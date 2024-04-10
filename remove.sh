#!/bin/bash

scr_dir="${0%/*}"
envs_dir="$scr_dir/environments"
mnames=$("$scr_dir/select-env.sh" "$1")

for mname in $mnames; do

   echo "Removing data for $mname..."
   rm -Rf "$envs_dir/$mname/data" "$envs_dir/$mname/src" "$envs_dir/$mname/backup.sql"
   db_vol_name=$(docker volume ls -q --filter "label=com.docker.compose.project=$mname" | grep db)
   [ -n "$db_vol_name" ] && echo "Clearing the database Docker volume... $(docker volume rm "$db_vol_name")"

done
