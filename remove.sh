#!/bin/bash

scr_dir="${0%/*}"
envs_dir="$scr_dir/environments"
mnames=$("$scr_dir/select-env.sh" "$1")

for mname in $mnames; do

   echo "Removing data for $mname..."
   rm -Rf "$envs_dir/$mname/data" "$envs_dir/$mname/db" "$envs_dir/$mname/src" "$envs_dir/$mname/backup.sql"

done
