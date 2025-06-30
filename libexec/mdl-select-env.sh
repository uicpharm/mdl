#!/bin/bash

. "${0%/*}/../lib/mdl-common.sh"

display_help() {
   cat <<EOF
Usage: $(script_name) <ENV>

Used by other scripts to verify a passed in Moodle environment, and interactively ask the
user to select an environment if a valid one is not passed in. So, if you request a
non-existent environment or don't pass an environment, it will give a selection list for
the user to select their environment.

Options:
-h, --help      Show this help message and exit.
EOF
}

[[ $* =~ -h || $* =~ --help ]] && display_help && exit

# Calculate all environments in the environments directory (just the local directory name)
envs=()
for d in "$MDL_ENVS_DIR"/*/; do
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
