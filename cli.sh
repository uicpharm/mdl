#!/bin/bash

scr_dir="${0%/*}"
mnames=$("$scr_dir"/select-env.sh "$1")

for mname in $mnames; do

   cmd="$2"

   if [ "$cmd" = "" ]; then
      echo -n "Command to run: "
      read -r cmd
   fi

   # Get an existing moodle task on this node
   container="$(docker ps -q -f name="${mname}_moodle" | head -1)"

   if [ -n "$container" ]; then
      docker exec -t "$container" php "/bitnami/moodle/admin/cli/$cmd.php" "${@:3}"
   else
      echo "Could not find a container running Moodle for $mname!"
      exit 1
   fi

done
