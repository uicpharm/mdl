#!/bin/bash

. "${0%/*}/../lib/mdl-common.sh"
running=''
runcnt=0

display_help() {
   cat <<EOF
Usage: $(script_name)

Returns which environment is active currently. Only returns an answer if there is a
single active environment.

Options:
-h, --help      Show this help message and exit.
EOF
}

[[ $* =~ -h || $* =~ --help ]] && display_help && exit

requires docker

while read -r dir; do
   mname=$(basename "$dir")
   if docker ps -f "label=com.docker.compose.project=$mname" --format '{{.Names}}' | grep -q moodle; then
      (( runcnt++ )) || true
      running="$mname"
   fi
done < <(find "$MDL_ENVS_DIR" -mindepth 1 -maxdepth 1 -type d)

[ $runcnt -eq 1 ] && echo "$running" || echo ''
