#!/bin/bash

. "${0%/*}/../lib/mdl-common.sh"

display_help() {
   cat <<EOF
Usage: $(script_name) <ENV>

Starts a Moodle environment.

Options:
-h, --help         Show this help message and exit.
-w, --wait         Pause until the environment fully starts.
-f, --follow       Jump into the environment's logs after starting.
-n, --no-start     Create the containers/volumes, but do not start.
-q, --quiet        Suppress output.
EOF
}

[[ $* =~ -h || $* =~ --help ]] && display_help && exit

requires docker docker-compose

mnames=$("$scr_dir/mdl-select-env.sh" "$1")
follow=false
quiet=false
start=true
wait=false
[[ $(docker --version) == podman* ]] && IS_PODMAN=true || IS_PODMAN=false

for arg in "$@"; do
   if [[ $arg == --wait || $arg == -w ]]; then
      wait=true
   elif [[ $arg == --follow || $arg == -f ]]; then
      follow=true
   elif [[ $arg == --quiet || $arg == -q ]]; then
      quiet=true
   elif [[ $arg == --no-start || $arg == -n ]]; then
      start=false
   fi
done

for mname in $mnames; do

   docker_compose_path=$("$scr_dir/mdl-calc-compose-path.sh" "$mname")
   $quiet || echo "Starting $mname..."
   . "$scr_dir/mdl-calc-images.sh" "$mname"
   export_env_and_update_config "$mname"

   # Explicitly add the pod so it has its lifecycle container and the exact name we want
   $IS_PODMAN && ! docker pod exists "$mname" && podman pod create --name "$mname"
   $IS_PODMAN && podman_args=('--podman-run-args' "--pod $mname")
   args=('-d')
   $start || args+=('--no-start')
   docker-compose "${podman_args[@]}" -f "$docker_compose_path" up "${args[@]}"

   if $wait; then
      # Do not exit until environment is fully running
      $quiet || echo -n "Waiting for $mname to fully start up"
      moodle_check=''
      while [ -z "$moodle_check" ]; do
         $quiet || echo -n '.'
         if ! moodle_check="$("$scr_dir/mdl-cli.sh" "$mname" checks --filter=core)"; then
            moodle_check=''
         fi
         [ -z "$moodle_check" ] && sleep 6
      done
      $quiet || echo ' Done!'
   fi
   if $follow; then
      "$scr_dir/mdl-logs.sh" "$mname" -f
   fi

   # Unset environment variables
   unset_env "$mname"

done
