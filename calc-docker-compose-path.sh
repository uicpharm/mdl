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

# Right now, all configs can use the same `docker-compose.yml` file, but if that changes,
# this script will inform scripts which file to use based on Moodle version.
realpath "$scr_dir/docker-compose.yml"
