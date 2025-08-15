#!/bin/bash

. "${0%/*}/../lib/mdl-common.sh"

display_help() {
   cat <<EOF
Usage: $(script_name) <ENV> [OPTIONS]

Stop a Moodle environment(s).

Options:
-h, --help         Show this help message and exit.
-q, --quiet        Suppress output.
EOF
}

[[ $* =~ -h || $* =~ --help ]] && display_help && exit
[[ $* =~ -q || $* =~ --quiet ]] && quiet=true || quiet=false

requires docker docker-compose

mnames=$("$scr_dir/mdl-select-env.sh" "${1:-$("$scr_dir/mdl-active-env.sh")}")
[[ $(docker --version) == podman* ]] && IS_PODMAN=true || IS_PODMAN=false

for mname in $mnames; do

   # Do not attempt if containers do not exist
   containers="$(docker ps -a -q -f name="$mname" 2> /dev/null)"
   if [ -z "$containers" ]; then
      $quiet || echo "The $mname stack is already stopped."
      continue
   fi

   docker_compose_path=$("$scr_dir/mdl-calc-compose-path.sh" "$mname")

   $quiet || echo "Stopping $mname..."
   . "$scr_dir/mdl-calc-images.sh" "$mname"
   export_env "$mname"
   $IS_PODMAN && podman_args=(--in-pod "$mname")
   docker-compose "${podman_args[@]}" -p "$mname" -f "$docker_compose_path" down
   # Since we explicitly add the pod via script, we must explicitly remove it
   $IS_PODMAN && docker pod exists "$mname" && podman pod rm -f "$mname"

   # Unset environment variables
   unset_env "$mname"

done
