#!/bin/bash

. "${0%/*}/../lib/mdl-common.sh"

display_help() {
   cat <<EOF
Usage: $(script_name) <ENV>

Looks at the version of a Moodle environment, based on its Git branch and custom configs,
and returns the full path of the compose file that should be used.

Options:
-h, --help      Show this help message and exit.
EOF
}

[[ $* =~ -h || $* =~ --help ]] && display_help && exit

requires realpath

# The default config for all versions is `default.yml` file. But if the environment config
# provides a specific compose file, use that one instead. Try first relative to the
# compose directory, then the absolute path.
realpath "$MDL_COMPOSE_DIR/default.yml"