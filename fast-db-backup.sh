#!/bin/bash

scr_dir="${0%/*}"
envs_dir="$scr_dir/environments"
backup_dir="$scr_dir/backup"
mnames=$("$scr_dir"/select-env.sh "$1")

echo '
WARNING: This makes a fast database backup, which is just a tar archive of the
filesystem. This should not be used for production purposes.
'

for mname in $mnames; do

   echo "Fast backup of the $mname database."

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

   env_dir="$envs_dir/$mname"
   db_target="${mname}_${label}_dbfiles.tar"
   tar c --no-xattrs -C "$env_dir/db" . > "$backup_dir/$db_target"

   echo "Fast backup of $mname is done!"

done
