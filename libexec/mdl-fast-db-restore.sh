#!/bin/bash

. "${0%/*}/../lib/mdl-common.sh"

display_help() {
   cat <<EOF
Usage: $(script_name) <ENV> [LABEL]

Restores a fast database backup, just overwriting the raw database files. $bold${red}This is unsafe
for production.$norm However, it can make the development cycle of restoring to a previous
state much faster; whereas you do need to restart the environment, the database will
start up instantaneously since it doesn't have to import a database dump file.

Options:
-h, --help         Show this help message and exit.
EOF
}

[[ $* =~ -h || $* =~ --help ]] && display_help && exit

requires docker

mnames=$("$scr_dir/mdl-select-env.sh" "$1")

echo '
WARNING: This is restoring a fast database backup, which is just restoring the
database filesystem. Whereas this often works in a dev environment, it should
never be used for production purposes.
'

for mname in $mnames; do

   # shellcheck source=../environments/sample.env
   . "$scr_dir/mdl-export-env.sh" "$mname"
   echo "Preparing to restore a fast database backup of $mname..."

   # Stop the services if they're running
   "$scr_dir/mdl-stop.sh" "$mname"
   echo

   # What timestamp of backup do they want? (Select from the list if they did not provide)
   labels=$(find "$MDL_BACKUP_DIR" -name "${mname}_*_dbfiles.tar" | cut -d"_" -f2- | sed -e "s/_dbfiles.tar//")
   [ -z "$labels" ] && echo "There are no fast backup files for $mname." && exit 1
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
   db_target="${mname}_${label}_dbfiles.tar"

   # Get database volume name, or, if it doesn't exist, make the name we expect it to be
   db_vol_name=$(docker volume ls -q --filter "label=com.docker.compose.project=$mname" | grep db)
   if [ -z "$db_vol_name" ]; then
      db_vol_name="${mname}_db"
   else
      docker volume rm "$db_vol_name" 2> /dev/null # If volume removal fails, its fine
   fi

   # Recreate volume and extract to the database volume
   docker volume create --label "com.docker.compose.project=$mname" "$db_vol_name"
   docker run --rm --privileged -v "$db_vol_name":/db -v "$MDL_BACKUP_DIR":/backup "$MDL_SHELL_IMAGE" tar xf "/backup/$db_target" -C /db

   echo "Done restoring the fast backup of database for $mname with label $label."

done
