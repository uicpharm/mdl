#!/bin/bash

. "${0%/*}/../lib/mdl-common.sh"

display_help() {
   cat <<EOF
Usage: $(script_name) <ENV>

Displays logs for all services for a given Moodle environment.

Options:
-h, --help         Show this help message and exit.
-f, --follow       Follow the logs in real time.
EOF
}

[[ $* =~ -h || $* =~ --help ]] && display_help && exit

requires "${MDL_CONTAINER_TOOL[0]}" "${MDL_COMPOSE_TOOL[0]}"
mname=$("$scr_dir/mdl-select-env.sh" "${1:-$("$scr_dir/mdl-active-env.sh")}" --no-all)

# Do not attempt if containers do not exist
containers="$(container_tool ps -q -f name="$mname" 2> /dev/null)"
[ -z "$containers" ] && echo "The $mname stack is not running." && exit 1

compose_path=$("$scr_dir/mdl-calc-compose-path.sh" "$mname")
[[ -z $compose_path ]] && exit 1
. "$scr_dir/mdl-calc-images.sh" "$mname"
export_env_and_update_config "$mname"
compose_tool -p "$mname" -f "$compose_path" logs "${@:2}"
