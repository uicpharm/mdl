#!/bin/bash

# Calculate all environments in the environments directory (just the local directory name)
envs_dir="${0%/*}/environments"
envs=()
for d in "$envs_dir"/*/; do
   envs+=("$(basename "$d")")
done

# Assign "targ" the first param. But don't allow "all" if they said "--no-all"
[[ "$*" == *"--no-all"* && "$1" == "all" ]] && targ="" || targ="$1"

# If env is invalid or empty, prompt for env. Unless they said "all"
if [[ "$(echo "${envs[*]}" | grep -w -- "$targ")" == "" && "$targ" != "all" ]]; then
   PS3="Select an environment: "
   [[ "$*" == *"--no-all"* ]] && all="" || all="all"
   # shellcheck disable=SC2048
   select mname in ${envs[*]} $all; do
      break
   done
else
   mname="$targ"
fi

# If "all", sub in a list of all envs
[ "$mname" = "all" ] && mname="${envs[*]}"

echo "$mname"
