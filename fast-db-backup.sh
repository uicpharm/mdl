#!/bin/bash

scr_dir="${0%/*}"
backup_dir="$scr_dir/backup"
mnames=$("$scr_dir"/select-env.sh "$1")

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
   branchver=$("$scr_dir"/moodle-version.sh "$mname")
   defaultlabel="local_${branchver}_$(date +"%Y%m%d")"
   label="$2"
   if [ "$label" = "" ]; then
     echo -n "Enter the label to put on the backup [$defaultlabel]: "
     read -r label
     label="${label:-$defaultlabel}"
   fi

   "$scr_dir/stop.sh" "$mname"

   db_target="${mname}_${label}_dbfiles.tar"
   docker run --rm -v "$db_vol_name":/db -v "$backup_dir":/backup docker.io/alpine:3 tar cf "/backup/$db_target" -C /db .

   echo "Fast backup of $mname is done!"

done
