#!/bin/bash

scr_dir="${0%/*}"
envs_dir="$scr_dir/environments"
backup_dir="$scr_dir/backup"
mnames=$("$scr_dir/select-env.sh" "$1")

for mname in $mnames; do

   env_dir="$envs_dir/$mname"
   # shellcheck source=environments/sample.env
   "$scr_dir/touch-env.sh" "$mname" && source "$env_dir/.env"
   echo "Preparing to restore $mname..."

   # Stop the services if they're running
   "$scr_dir/stop.sh" "$mname"

   # What timestamp of backup do they want? (Select from the list if they did not provide)
   labels="$(find "$backup_dir" -name "${mname}_*_src.*" | cut -d"_" -f2- | sed -e "s/_src\..*//" | uniq)"
   [ -z "$labels" ] && echo "There are no backup files for $mname." && exit 1
   label="$2"
   # Even if they provided a label, prompt them if its not a label in the list
   if [ "$(echo "$labels" | grep "^$label\$")" = "" ]; then
      PS3="Select the label of the backup to restore: "
      select label in $labels; do
         break
      done
   fi
   echo "Restoring $mname with label $label... "

   # Backup targets
   data_target="${mname}_${label}_data.tar"
   [ -f "$backup_dir/$data_target" ] || data_target="$data_target.bz2"
   src_target="${mname}_${label}_src.tar"
   [ -f "$backup_dir/$src_target" ] || src_target="$src_target.bz2"
   db_target="${mname}_${label}_db.sql"
   [ -f "$backup_dir/$db_target" ] || db_target="$db_target.bz2"
   echo "  - ${data_target}"
   echo "  - ${src_target}"
   echo "  - ${db_target}"

   # Docker environment paths
   data_path="$env_dir/data"
   db_path="$env_dir/db"
   src_path="$env_dir/src"
   sql_path="$env_dir/backup.sql"

   # Clear existing work files
   rm -Rf "$data_path" "$src_path" "$db_path" "$sql_path"

   # Checks
   docker_exists="$(grep -w 1001 /etc/passwd)"
   arch="$(uname)"

   # Set up the directory for the Moodle environment
   mkdir -p "$data_path/sessions"
   mkdir -p "$data_path/trashdir"
   mkdir -p "$data_path/temp"
   mkdir -p "$data_path/localcache"
   mkdir -p "$data_path/cache"
   mkdir -p "$src_path"
   mkdir -p "$db_path" && [ "$arch" = "Linux" ] && chown 1001 "$db_path"

   # In all of these file restores, we only follow up with changing ownership if
   # it is indeed a Linux server. Other dev environments don't need it.

   # Extract SQL backup file, which docker-compose file points to for restore
   if [[ "$db_target" =~ \.bz2$ ]]; then
      bunzip2 -c "$backup_dir/$db_target" > "$sql_path" && \
         [ -n "$docker_exists" ] && [ "$arch" = "Linux" ] && chown 1001 "$sql_path" &
   else
      cp "$backup_dir/$db_target" "$sql_path" && \
         [ -n "$docker_exists" ] && [ "$arch" = "Linux" ] && chown 1001 "$sql_path"
   fi

   # Extract source and data. Give ownership to daemon process (1).
   tar xf "$backup_dir/$data_target" -C "$data_path" && \
      [ "$arch" = "Linux" ] && chown -R 1 "$data_path" &
   tar xf "$backup_dir/$src_target" -C "$src_path" && \
      [ "$arch" = "Linux" ] && chown -R 1 "$src_path" &

   wait

   # Update Moodle config
   "$scr_dir/update-config.sh" "$mname"

   echo "Done restoring $mname with label $label."

done
