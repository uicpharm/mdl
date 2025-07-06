#!/bin/bash

. "${0%/*}/util/common.sh"

display_help() {
   cat <<EOF
Usage: $(script_name) <ENV>

Stop a Moodle environment(s).

Options:
-h, --help         Show this help message and exit.
EOF
}

[[ $* =~ -h || $* =~ --help ]] && display_help && exit

activemname=$("$scr_dir/active-env.sh")
mnames=$("$scr_dir/select-env.sh" "${1:-$activemname}")
[[ $(docker --version) == podman* ]] && IS_PODMAN=true || IS_PODMAN=false

for mname in $mnames; do

   # Do not attempt if containers do not exist
   containers="$(docker ps -q -f name="$mname" 2> /dev/null)"
   [ -z "$containers" ] && echo "The $mname stack is already stopped." && continue

   docker_compose_path=$("$scr_dir/calc-docker-compose-path.sh" "$mname")

   echo "Stopping $mname..."
   . "$scr_dir/calc-images.sh" "$mname"
   . "$scr_dir/export-env.sh" "$mname"
   (cd "$scr_dir" && docker-compose -f "$docker_compose_path" down "${@:2}")
   # Since we explicitly add the pod via script, we must explicitly remove it
   # shellcheck disable=SC2015
   $IS_PODMAN && docker pod exists "$mname" && podman pod rm -f "$mname" || true

done
