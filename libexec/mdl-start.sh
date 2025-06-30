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
EOF
}

[[ $* =~ -h || $* =~ --help ]] && display_help && exit

mnames=$("$scr_dir/mdl-select-env.sh" "$1")
follow=false
wait=false
[[ $(docker --version) == podman* ]] && IS_PODMAN=true || IS_PODMAN=false

for arg in "$@"; do
   if [[ $arg == --wait || $arg == -w ]]; then
      wait=true
   elif [[ $arg == --follow || $arg == -f ]]; then
      follow=true
   fi
done

for mname in $mnames; do

   docker_compose_path=$("$scr_dir/mdl-calc-compose-path.sh" "$mname")
   echo "Starting $mname..."
   . "$scr_dir/mdl-calc-images.sh" "$mname"
   . "$scr_dir/mdl-export-env.sh" "$mname"

   # Explicitly add the pod so it has its lifecycle container and the exact name we want
   $IS_PODMAN && ! docker pod exists "$mname" && podman pod create --name "$mname"
   $IS_PODMAN && podman_args=('--podman-run-args' "--pod $mname")
   docker-compose "${podman_args[@]}" -f "$docker_compose_path" up -d

   if $wait; then
      # Do not exit until environment is fully running
      echo -n "Waiting for $mname to fully start up"
      moodle_check=''
      while [ -z "$moodle_check" ]; do
         echo -n '.'
         if ! moodle_check="$("$scr_dir/mdl-cli.sh" "$mname" checks --filter=core)"; then
            moodle_check=''
         fi
         [ -z "$moodle_check" ] && sleep 6
      done
      echo ' Done!'
   fi
   if $follow; then
      "$scr_dir/mdl-logs.sh" "$mname" -f
   fi

done
