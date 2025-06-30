#!/bin/bash

. "${0%/*}/../lib/mdl-common.sh"

display_help() {
   cat <<EOF
Usage: $(script_name) <ENV> [LABEL]

Makes a fast database backup, which is just a tar archive of the raw database files. The
reason this is fast is because the archive process is faster than a database dump, and
because the restore process directly restores the database files, as opposed to the
traditional restore which saves the dump in the environment and requires the dump to be
processed by the database container on startup.
$bold$red
This is unsafe for production but often works fine for development purposes.
$norm
Options:
-h, --help         Show this help message and exit.
EOF
}

[[ $* =~ -h || $* =~ --help ]] && display_help && exit

mnames=$("$scr_dir"/mdl-select-env.sh "$1")

echo '
WARNING: This makes a fast database backup, which is just a tar archive of the
filesystem. This should not be used for production purposes.
'

for mname in $mnames; do

   echo "Fast backup of the $mname database."

   # Abort if the volume can't be found
   db_vol_name=$(docker volume ls -q --filter "label=com.docker.compose.project=$mname" | grep db)
   if [ -z "$db_vol_name" ]; then
      echo "Database volume for $mname could not be found."
      exit 1
   fi

   # What label on the backup do they want? (Defaults to "local_branchver_yyyymmdd")
   branchver=$("$scr_dir"/mdl-moodle-version.sh "$mname")
   defaultlabel="local_${branchver}_$(date +"%Y%m%d")"
   label="$2"
   if [ "$label" = "" ]; then
     echo -n "Enter the label to put on the backup [$defaultlabel]: "
     read -r label
     label="${label:-$defaultlabel}"
   fi

   "$scr_dir/mdl-stop.sh" "$mname"

   db_target="${mname}_${label}_dbfiles.tar"
   docker run --rm --privileged -v "$db_vol_name":/db -v "$MDL_BACKUP_DIR":/backup docker.io/alpine:3 tar cf "/backup/$db_target" -C /db .

   echo "Fast backup of $mname is done!"

done
