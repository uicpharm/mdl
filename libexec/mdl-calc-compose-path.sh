#!/bin/bash

. "${0%/*}/../lib/mdl-common.sh"

display_help() {
   cat <<EOF
Usage: $(script_name) <ENV>

Looks at the version of a Moodle environment, based on its Git branch, and returns the
full path of the ${ul}compose.yml${rmul} file that should be used.

Options:
-h, --help      Show this help message and exit.
EOF
}

[[ $* =~ -h || $* =~ --help ]] && display_help && exit

requires realpath

# Right now, all configs can use the same `compose.yml` file, but if that changes,
# this script will inform scripts which file to use based on Moodle version.
realpath "$MDL_COMPOSE_DIR/compose.yml"
