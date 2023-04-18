#!/bin/bash

scr_dir="${0%/*}"
mnames=$("$scr_dir/select-env.sh" "${1:-all}")
norm="$(tput sgr0)"
ul="$(tput smul)"
bold="$(tput bold)"

for mname in $mnames; do

   if [ -n "$(docker service ls -q -f name="$mname")" ]; then
      echo "The ${bold}$mname${norm} environment is running:"
      docker stack services "$mname"
      echo
   else
      echo "The ${bold}$mname${norm} environment is ${ul}not running${norm}."
   fi

done
