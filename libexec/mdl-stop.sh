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

requires "${MDL_CONTAINER_TOOL[0]}" "${MDL_COMPOSE_TOOL[0]}"

mnames=$("$scr_dir/mdl-select-env.sh" "${1:-$("$scr_dir/mdl-active-env.sh")}")
[[ $(container_tool --version) == podman* ]] && IS_PODMAN=true || IS_PODMAN=false

for mname in $mnames; do

   # Do not attempt if containers do not exist
   containers="$(container_tool ps -a -q -f name="$mname" 2> /dev/null)"
   if [ -z "$containers" ]; then
      $quiet || echo "The $mname stack is already stopped."
      continue
   fi

   compose_path=$("$scr_dir/mdl-calc-compose-path.sh" "$mname")
   [[ -z $compose_path ]] && continue

   $quiet || echo "Stopping $mname..."
   . "$scr_dir/mdl-calc-images.sh" "$mname"
   export_env "$mname"
   $IS_PODMAN && podman_args=(--in-pod "$mname")
   compose_tool "${podman_args[@]}" -p "$mname" -f "$compose_path" down
   # Since we explicitly add the pod via script, we must explicitly remove it
   $IS_PODMAN && container_tool pod exists "$mname" && container_tool pod rm -f "$mname"

   # Unset environment variables
   unset_env "$mname"

done
