#!/bin/bash

scr_dir="${0%/*}"
mname=$("$scr_dir"/select-env.sh "$1" --no-all)
branchver=$("$scr_dir/moodle-version.sh" "$mname")
[[ "$branchver" -lt "401" ]] && ver=3.9.2 || ver=4.1.2
realpath "$scr_dir/docker-compose-$ver.yml"
