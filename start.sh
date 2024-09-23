#!/bin/bash

. "${0%/*}/util/common.sh"
mnames=$("$scr_dir/select-env.sh" "$1")
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

   docker_compose_path=$("$scr_dir/calc-docker-compose-path.sh" "$mname")
   echo "Starting $mname..."
   . "$scr_dir/export-env.sh" "$mname"

   # Explicitly add the pod so it has its lifecycle container and the exact name we want
   $IS_PODMAN && ! docker pod exists "$mname" && podman pod create --name "$mname"
   $IS_PODMAN && podman_args=('--podman-run-args' "--pod $mname")
   (cd "$scr_dir" && docker-compose "${podman_args[@]}" -f "$docker_compose_path" up -d)

   if $wait; then
      # Do not exit until environment is fully running
      echo -n "Waiting for $mname to fully start up"
      moodle_check=''
      while [ -z "$moodle_check" ]; do
         echo -n '.'
         if ! moodle_check="$("$scr_dir/cli.sh" "$mname" checks --filter=core)"; then
            moodle_check=''
         fi
         [ -z "$moodle_check" ] && sleep 6
      done
      echo ' Done!'
   fi
   if $follow; then
      "$scr_dir/logs.sh" "$mname" -f
   fi

done
