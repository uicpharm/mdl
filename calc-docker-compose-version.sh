#!/bin/bash

scr_dir="${0%/*}"
envs_dir="$scr_dir/environments"
mname=$("$scr_dir"/select-env.sh "$1" --no-all)
branchver="0"
if [ -d "$envs_dir/$mname/src" ]; then
   cd "$envs_dir/$mname/src" || exit 1
   branchver="$(git symbolic-ref --short HEAD | cut -d"_" -f2)"
fi
[[ -z "$branchver" || "$branchver" -lt "401" ]] && echo "3.9.2" || echo "4.1.2"
