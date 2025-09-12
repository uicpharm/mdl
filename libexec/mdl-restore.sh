#!/bin/bash

. "${0%/*}/../lib/mdl-common.sh"

display_help() {
   cat <<EOF
Usage: $(script_name) <ENV> [LABEL]

Restores a backup in the ${ul}backup$rmul folder to a local Moodle environment, unless
you specify to download from ${ul}Box.com$rmul with the ${bold}--box$norm option. This also will
include updating the config file for the Docker environment.

Options:
-h, --help         Show this help message and exit.
-b, --box          Use backup sets in Box instead of the local backup folder.
-x, --extract      If compressed, leave the decompressed files when done extracting them.
-r, --rm           Remove the local copy of the backup when done.
EOF
}

[[ $* =~ -h || $* =~ --help ]] && display_help && exit
[[ $* =~ -b || $* =~ --box ]] && box=true || box=false
[[ $* =~ -x || $* =~ --extract ]] && extract=true || extract=false
[[ $* =~ -r || $* =~ --rm ]] && remove_when_done=true || remove_when_done=false

# Check necessary utilities
requires "${MDL_CONTAINER_TOOL[0]}" tar bzip2 gzip xz find sed grep uniq

mnames=$("$scr_dir/mdl-select-env.sh" "$1")

for mname in $mnames; do

   env_dir="$MDL_ENVS_DIR/$mname"
   export_env "$mname"
   echo -e "$bold$ul\nRestore $mname$norm"

   # Get a list of all files (and corresponding labels) from the desired source (local or box).
   # $files lists from the desired source (local or box), $local_files is always local.
   local_files=$(find "$MDL_BACKUP_DIR" -name "${mname}_*_*.*")
   $box && files=$("$scr_dir/mdl-box.sh" "$mname" ls) || files=$local_files
   local_files=$(echo "$local_files" | xargs -r -n1 basename)
   files=$(echo "$files" | xargs -r -n1 basename)
   src_files=$(echo "$files" | awk -F'_' '$3 ~ /src/')
   labels="$(echo "$src_files" | cut -d"_" -f2- | sed -e "s/_src\..*//" | uniq | sort)"

   # What timestamp of backup do they want? (Select from the list if they did not provide)
   $box && backup_source_desc='Box.com' || backup_source_desc='local'
   [ -z "$labels" ] && echo "There are no $backup_source_desc backup files for $mname." && exit 1
   label="$2"
   # Even if they provided a label, prompt them if its not a label in the list
   if [ "$(echo "$labels" | grep "^$label\$")" = "" ]; then
      PS3="Select the label of the $backup_source_desc backup to restore: "
      select label in $labels; do
         break
      done
   fi

   # Backup targets
   declare data_target src_target db_target # Explicitly declared to make shellcheck happy
   for t in data src db; do
      target="${t}_target"; local_target="local_${t}_target"
      declare $target= $local_target=
      # Find filenames of target files
      while IFS= read -r file; do
         [[ -z ${!target} && $file =~ ^${mname}_${label}_${t}\. ]] && declare $target="$file"
      done <<< "$files"
      # Find filenames of local files, in case we're looking in Box
      while IFS= read -r file; do
         [[ $file =~ ^${mname}_${label}_${t}\. ]] && declare $local_target="$file"
      done <<< "$local_files"
   done

   # List (and if requested, download from Box) each target. Abort if a target can't be found.
   echo "Using $backup_source_desc backup set with label $ul$label$rmul:"
   for t in data src db; do
      target="${t}_target"; local_target="local_${t}_target"
      echo "  - $bold$t:$norm ${!target:-${red}Not found, so we will abort$norm}"
      # If target is not found, abort. Otherwise, download if Box.com is the source.
      if [[ -z ${!target} ]]; then
         exit 1
      elif $box; then
         "$scr_dir/mdl-box.sh" "$mname" download "${!target}" "$MDL_BACKUP_DIR/${!target}" && \
         # If a similar, but not the same, local file existed, delete it.
         # i.e. "mymoodle_daily_src.tar" and "mymoodle_daily_src.tar.bz2" and "mymoodle_daily_src.tar.gz" are "similar" files.
         [[ -n ${!local_target} && ${!local_target} != "${!target}" ]] && echo "Removing similar local file ${!local_target}." && \
         rm -f "$MDL_BACKUP_DIR/${!local_target}"
      fi
      # If `extract` is requested, decompress the files
      if $extract && new_target=$(decompress "$MDL_BACKUP_DIR/${!target}"); then
         declare $target="$(basename "$new_target")"
         echo "    - Extracted $ul${!target}$rmul."
      fi
   done

   # Stop the services if they're running
   "$scr_dir/mdl-stop.sh" "$mname"

   # Clear existing volumes
   "$scr_dir/mdl-remove.sh" "$mname"

   echo 'Determining Moodle version from source...'

   # Restore src to a temp volume first, to retrieve the git branch version
   temp_vol_name="${mname}_temp"
   container_tool volume rm -f "$temp_vol_name" > /dev/null
   container_tool run --rm --name "${mname}_worker_tar_src" -v "$temp_vol_name":/src -v "$MDL_BACKUP_DIR":/backup:Z,ro "$MDL_SHELL_IMAGE" \
      tar xf "/backup/$src_target" -C /src
   branchver=$(src_vol_name="$temp_vol_name" "$scr_dir/mdl-moodle-version.sh" "$mname")
   . "$scr_dir/mdl-calc-images.sh" "$mname"

   echo 'Creating containers and volumes for restore...'

   # Create the stack, so we have the volumes that are auto-attached to the stack
   branchver="$branchver" "$scr_dir/mdl-start.sh" "$mname" -q -n

   # Find all the volume names
   vols=$(container_tool volume ls -q --filter "label=com.docker.compose.project=$mname")
   db_vol_name=$(grep db <<< "$vols")
   data_vol_name=$(grep data <<< "$vols")
   src_vol_name=$(grep src <<< "$vols")

   # Extract src and data to their volumes, set permissions appropriately.
   # Ref: https://docs.moodle.org/4x/sv/Security_recommendations#Running_Moodle_on_a_dedicated_server
   echo "Restoring $ul$src_vol_name$norm and $ul$data_vol_name$norm volumes..."
   container_tool run --rm --name "${mname}_worker_tar_data" -v "$data_vol_name":/data -v "$MDL_BACKUP_DIR":/backup:Z,ro "$MDL_SHELL_IMAGE" \
      sh -c "\
         mkdir -p /data/sessions /data/trashdir /data/temp /data/localcache /data/cache
         tar xf '/backup/$data_target' -C /data
         chown -R daemon:daemon /data
         find /data -type d -print0 | xargs -0 chmod 700
         find /data -type f -print0 | xargs -0 chmod 600
      " &
   pid_data=$!
   container_tool run --rm --name "${mname}_worker_cp_src" -v "$src_vol_name":/src -v "$temp_vol_name":/temp:ro "$MDL_SHELL_IMAGE" \
      sh -c "\
         cp -Rf /temp/. /src
         chown -R daemon:daemon /src
         find /src -type d -print0 | xargs -0 chmod 755
         find /src -type f -print0 | xargs -0 chmod 644
      " &
   pid_src=$!

   # Start a MariaDB container to restore the database
   (
      echo "Restoring $ul$db_vol_name$norm volume..."
      sql_path="$(mktemp -d)/${mname}_backup.sql"
      if ! decompress "$MDL_BACKUP_DIR/$db_target" "$sql_path" -k > /dev/null; then
         # If decompression fails, it probably isn't compressed. Point at original file instead.
         sql_path="$MDL_BACKUP_DIR/$db_target"
      fi
      db_runner="${mname}_worker_db_restore"
      container_tool run -d --rm --name "$db_runner" \
         --privileged \
         -e MARIADB_ROOT_PASSWORD="${ROOT_PASSWORD:-password}" \
         -e MARIADB_USER="${DB_USERNAME:-moodleuser}" \
         -e MARIADB_PASSWORD="${DB_PASSWORD:-password}" \
         -e MARIADB_DATABASE="${DB_NAME:-moodle}" \
         -e MARIADB_COLLATE=utf8mb4_unicode_ci \
         -e MARIADB_SKIP_TEST_DB=yes \
         -v "$db_vol_name":/bitnami/mariadb \
         -v "$sql_path":/docker-entrypoint-initdb.d/restore.sql:Z,ro \
         "$MARIADB_IMAGE" > /dev/null
      # MariaDB doesn't have a "run task and exit" mode, so we just wait until
      # the logs indicate it has finished, then we stop it.
      last_check=0
      until container_tool logs --since "$last_check" "$db_runner" 2>&1 | grep -q 'MariaDB setup finished'; do
         last_check=$(($(date +%s)-1))
         sleep 5
      done
      container_tool stop "$db_runner" > /dev/null
   ) &
   db_pid=$!

   # When done, clean up. Down the stack and remove the temp volume.
   wait $pid_src
   container_tool volume rm -f "$temp_vol_name" > /dev/null
   wait $pid_data $db_pid
   branchver="$branchver" "$scr_dir/mdl-stop.sh" "$mname" -q

   # Remove the local backup files when done, if they specified that option
   if $remove_when_done; then
      echo Removing local backup files...
      rm -fv "$MDL_BACKUP_DIR/$data_target" "$MDL_BACKUP_DIR/$src_target" "$MDL_BACKUP_DIR/$db_target"
   fi

   # Update Moodle config
   export_env_and_update_config "$mname"

   echo "Done restoring $ul$mname$rmul from $backup_source_desc backup set with label $ul$label$norm."

   # Unset environment variables
   unset_env "$mname"

done
