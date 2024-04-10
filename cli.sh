#!/bin/bash

scr_dir="${0%/*}"
paramI=''
for arg in "$@"; do
   if [ "$arg" = "-i" ]; then
      paramI='-i'
      shift
      break
   fi
done
mnames=$("$scr_dir"/select-env.sh "$1")

for mname in $mnames; do

   cmd="$2"

   if [ "$cmd" = "" ]; then
      echo -n "Command to run: "
      read -r cmd
   fi

   # Get an existing moodle task on this node
   container="$(docker ps -f "label=com.docker.compose.project=$mname" --format '{{.Names}}' | grep moodle | head -1)"

   if [ -n "$container" ]; then
      docker exec $paramI -t "$container" php "/bitnami/moodle/admin/cli/$cmd.php" "${@:3}"
   else
      echo "Could not find a container running Moodle for $mname!"
      exit 1
   fi

done
