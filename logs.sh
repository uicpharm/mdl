#!/bin/bash

scr_dir="${0%/*}"
activemname=$("$scr_dir/active-env.sh")
mname=$("$scr_dir/select-env.sh" "${1:-$activemname}" --no-all)

# Do not attempt if containers do not exist
containers="$(docker ps -q -f name="$mname" 2> /dev/null)"
[ -z "$containers" ] && echo "The $mname stack is not running." && exit 1

env_dir="$scr_dir/environments/$mname"
ver=$("$scr_dir/calc-docker-compose-version.sh" "$mname")
docker-compose -f "$env_dir/docker-compose-$ver.yml" logs "${@:2}"
