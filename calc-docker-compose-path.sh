#!/bin/bash

. "${0%/*}/util/common.sh"

display_help() {
   cat <<EOF
Usage: $(script_name) <ENV>

Looks at the version of a Moodle environment, based on its Git branch, and returns the
full path of the ${ul}docker-compose.yml${rmul} file that should be used.

Options:
-h, --help      Show this help message and exit.
EOF
}

[[ $* =~ -h || $* =~ --help ]] && display_help && exit

mname=$("$scr_dir"/select-env.sh "$1" --no-all)
branchver=$("$scr_dir/moodle-version.sh" "$mname")
[[ "$branchver" -lt "401" ]] && ver=3.9.2 || ver=4.1.2
realpath "$scr_dir/docker-compose-$ver.yml"
