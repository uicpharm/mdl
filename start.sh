#!/bin/bash

scr_dir="${0%/*}"
envs_dir="$scr_dir/environments"
mnames=$("$scr_dir/select-env.sh" "$1")
wait=false

for arg in "$@"; do
   if [ "$arg" == "--wait" ]; then
      wait=true
      break
   fi
done

for mname in $mnames; do

   ver=$("$scr_dir/calc-docker-compose-version.sh" "$mname")
   echo "Starting $mname..."
   # We touch the .env file since technically `docker compose config` will look at it.
   env_dir="$envs_dir/$mname"
   "$scr_dir/touch-env.sh" "$mname"
   # Use `--with-registry-auth` to ensure Docker uses authentication to our ghcr.io repo.
   # Use `--resolve-image never` for deploy to work on arm64 computers. Production VMs are amd64, and Macs can run amd64 in emulation.
   # Get configs from `docker compose config` so we can pull in environment file settings.
   docker stack deploy --with-registry-auth --resolve-image never -c <(docker compose -f "$env_dir/docker-compose-$ver.yml" config | sed '/^name/d' | sed '/bind:/d' | sed '/create_host_path:/d' | sed -e '/published/ s/"//g') "$mname"

   if [ "$wait" == true ]; then
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

done
