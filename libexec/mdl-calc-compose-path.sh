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
mname=$("$scr_dir/mdl-select-env.sh" "$1" --no-all)
export_env "$mname"

# The default config for all versions is `default.yml` file. But if the environment config
# provides a specific compose file, use that one instead. First try setting the path
# relative to the compose directory, and if that doesn't exist (throws an error), then use
# the absolute path.
compose_file=${COMPOSE_FILE:-default.yml}
if [[ -f "$MDL_COMPOSE_DIR/$compose_file" ]]; then
   compose_path="$MDL_COMPOSE_DIR/$compose_file"
else
   abs="$(realpath "$compose_file" 2>/dev/null)"
   [[ -f $abs ]] && compose_path=$abs
fi
if [[ -n $compose_path ]]; then
   echo "$compose_path"
else
   echo "${red}Could not find compose file $ul$compose_file$rmul for $ul$mname$rmul.$norm" >&2
   exit 1
fi
