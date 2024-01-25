#!/bin/bash

scr_dir="${0%/*}"
backup_dir="$scr_dir/backup"
envs_dir=$(realpath -q "$scr_dir/environments")
mnames=$("$scr_dir/select-env.sh" "${1:-all}")
norm="$(tput sgr0)"
ul="$(tput smul)"
bold="$(tput bold)"
red="$(tput setaf 1)"
green="$(tput setaf 2)"
ok=true

for mname in $mnames; do

   running="$(docker service ls -q -f name="$mname")"
   labels="$(find "$backup_dir" -name "${mname}_*_src.*" | cut -d"_" -f2- | sed -e "s/_src\..*//" | uniq)"
   fast_labels=$(find "$backup_dir" -name "${mname}_*_dbfiles.tar" | cut -d"_" -f2- | sed -e "s/_dbfiles.tar//")
   data_dir="$envs_dir/$mname/data"
   src_dir="$envs_dir/$mname/src"
   db_vol_name=$(docker volume ls -q --filter "label=com.docker.stack.namespace=$mname" --filter "name=db")

   echo "${ul}Environment: $bold$mname$norm"
   # Status
   if [ -n "$running" ]; then
      echo "Status: ${green}running${norm}"
   else
      echo "Status: ${red}not running${norm}"
      ok=false
   fi
   # Path info
   [ -d "$data_dir" ] && data_status="${green}exists" || data_status="${red}missing"
   [ -d "$src_dir" ] && src_status="${green}exists" || src_status="${red}missing"
   [ -n "$db_vol_name" ] && db_status="${green}exists" || db_status="${red}missing"
   # If db volume was not found, set the name to what it should've been
   [ -z "$db_vol_name" ] && db_vol_name="${mname}_db"
   echo "Paths:"
   echo "  - $data_dir ($data_status$norm)"
   echo "  - $src_dir ($src_status$norm)"
   echo "  - $db_vol_name ($db_status$norm)"
   # Normal Backups
   if [ -z "$labels" ]; then
      echo "Backups: none"
   else
      echo "Backups:"
      for label in $labels; do
         echo "  - $label"
      done
   fi
   # Fast Database Backups
   if [ -n "$fast_labels" ]; then
      echo "Fast Database Backups:"
      for label in $fast_labels; do
         echo "  - $label"
      done
   fi
   # If running, the services list
   if [ -n "$running" ]; then
      echo
      docker stack services "$mname"
   fi
   echo

done

# If an environment was not running, exit as an error
[ "$ok" == true ] && exit 0 || exit 1
