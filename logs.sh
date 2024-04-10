#!/bin/bash

scr_dir="${0%/*}"
activemname=$("$scr_dir/active-env.sh")
mname=$("$scr_dir/select-env.sh" "${1:-$activemname}" --no-all)

# Do not attempt if containers do not exist
containers="$(docker ps -q -f name="$mname" 2> /dev/null)"
[ -z "$containers" ] && echo "The $mname stack is not running." && exit 1

docker_compose_path=$("$scr_dir/calc-docker-compose-path.sh" "$mname")
. "$scr_dir/export-env.sh" "$mname"
(cd "$scr_dir" && docker-compose -f "$docker_compose_path" logs "${@:2}")
