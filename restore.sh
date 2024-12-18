#!/bin/bash

. "${0%/*}/util/common.sh"

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

mnames=$("$scr_dir/select-env.sh" "$1")

for mname in $mnames; do

   env_dir="$envs_dir/$mname"
   # shellcheck source=environments/sample.env
   . "$scr_dir/export-env.sh" "$mname"
   echo -e "$bold$ul\nRestore $mname$norm"

   # Get a list of all files (and corresponding labels) from the desired source (local or box).
   # $files lists from the desired source (local or box), $local_files is always local.
   local_files=$(find "$backup_dir" -name "${mname}_*_*.*")
   $box && files=$("$scr_dir/box.sh" "$mname" ls) || files=$local_files
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
         "$scr_dir/box.sh" "$mname" download "${!target}" "$backup_dir/${!target}" && \
         # If a similar, but not the same, local file existed, delete it.
         # i.e. "medce_daily_src.tar" and "medce_daily_src.tar.bz2" and "medce_daily_src.tar.gz" are "similar" files.
         [[ -n ${!local_target} && ${!local_target} != "${!target}" ]] && echo "Removing similar local file ${!local_target}." && \
         rm -f "$backup_dir/${!local_target}"
      fi
      # If `extract` is requested, decompress the files
      if $extract && new_target=$(decompress "$backup_dir/${!target}"); then
         declare $target="$(basename "$new_target")"
         echo "    - Extracted $ul${!target}$rmul."
      fi
   done

   # Docker environment paths
   data_path="$env_dir/data"
   src_path="$env_dir/src"
   sql_path="$env_dir/backup.sql"

   # Stop the services if they're running
   "$scr_dir/stop.sh" "$mname"

   # Clear existing work files
   "$scr_dir/remove.sh" "$mname"

   # Checks
   docker_id="$(id -u docker 2>/dev/null)"

   # Set up the directory for the Moodle environment
   mkdir -p "$data_path/sessions"
   mkdir -p "$data_path/trashdir"
   mkdir -p "$data_path/temp"
   mkdir -p "$data_path/localcache"
   mkdir -p "$data_path/cache"
   mkdir -p "$src_path"

   echo Restoring...

   # Extract SQL backup file, which docker-compose file points to for restore
   (
      # If the decompression fails, that probably means it isn't compressed.
      # Copy the original file instead.
      if ! decompress "$backup_dir/$db_target" "$sql_path" -k > /dev/null; then
         cp "$backup_dir/$db_target" "$sql_path"
      fi && \
      [ -n "$docker_id" ] && chown "$docker_id" "$sql_path"
   ) &

   # Extract source and data.
   tar xf "$backup_dir/$data_target" -C "$data_path" &
   tar xf "$backup_dir/$src_target" -C "$src_path" &

   wait

   # Remove the local backup files when done, if they specified that option
   if $remove_when_done; then
      echo Removing local backup files...
      rm -fv "$backup_dir/$data_target" "$backup_dir/$src_target" "$backup_dir/$db_target"
   fi

   # Update Moodle config
   "$scr_dir/update-config.sh" "$mname"

   echo "Done restoring $ul$mname$rmul from $backup_source_desc backup set with label $ul$label$norm."

done
