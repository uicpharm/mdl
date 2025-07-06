#!/bin/bash

. "${0%/*}/util/common.sh"
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

for dir in "$envs_dir"/*/
do
   mname=$(basename "$dir")
   if docker ps -f "label=com.docker.compose.project=$mname" --format '{{.Names}}' | grep -q moodle; then
      (( runcnt++ )) || true
      running="$mname"
   fi
done

[ $runcnt -eq 1 ] && echo "$running" || echo ''
