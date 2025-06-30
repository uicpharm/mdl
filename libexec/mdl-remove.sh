#!/bin/bash

. "${0%/*}/../lib/mdl-common.sh"

display_help() {
   cat <<EOF
Usage: $(script_name) <ENV> [LABEL]

Deletes/removes files for a given Moodle environment. If you specify a backup label, it
will remove the backup set instead of the Moodle environment itself.

Options:
-h, --help         Show this help message and exit.

$ul${bold}Examples$norm

Remove a Moodle environment:
   $bold$(script_name) \$mname$norm

Remove just this backup set for the Moodle environment:
   $bold$(script_name) \$mname 20240920$norm
EOF
}

[[ $* =~ -h || $* =~ --help ]] && display_help && exit

# Parameter #1: Environment
mnames=$("$scr_dir/mdl-select-env.sh" "$1")
[[ $1 == all || $1 == "$mnames" ]] && shift

# Parameter #2: Label, multiple can be provided
labels="$*"

for mname in $mnames; do

   if [ -n "$labels" ]; then
      # Remove a backup by environment/label
      for label in $labels; do
         echo "Removing backup for $mname with label $label..."
         for file_type in src data db dbfiles; do
            rm -fv "$MDL_BACKUP_DIR/${mname}_${label}_${file_type}".*
         done
      done
   else
      # Remove a moodle environment
      echo "Removing data for $mname environment..."
      rm -Rf "$MDL_ENVS_DIR/$mname/data" "$MDL_ENVS_DIR/$mname/src" "$MDL_ENVS_DIR/$mname/backup.sql"
      db_vol_name=$(docker volume ls -q --filter "label=com.docker.compose.project=$mname" | grep db)
      [ -n "$db_vol_name" ] && echo "Clearing the database Docker volume... $(docker volume rm "$db_vol_name")"
   fi
done
