#!/bin/bash

scr_dir="${0%/*}"
activemname=$("$scr_dir/active-env.sh")
mnames=$("$scr_dir/select-env.sh" "${1:-$activemname}")

for mname in $mnames; do

   # Do not attempt if containers do not exist
   containers="$(docker stack ps -q "$mname" 2> /dev/null)"
   [ -z "$containers" ] && echo "The $mname stack is already stopped." && continue

   echo "Stopping $mname..."
   docker stack rm "$mname" "${@:2}"

   # Do not exit until containers are stopped
   echo -n "Waiting for $mname containers to be destroyed..."
   while [ -n "$containers" ]; do
      sleep 1
      echo -n .
      containers="$(docker stack ps -q "$mname" 2> /dev/null)"
   done
   echo ' Done!'

done
