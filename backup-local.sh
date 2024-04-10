#!/bin/bash

scr_dir="${0%/*}"
envs_dir="$scr_dir/environments"
backup_dir="$scr_dir/backup"
mnames=$("$scr_dir"/select-env.sh "$1")

for mname in $mnames; do

   env_dir="$envs_dir/$mname"
   container=$(docker ps -f "label=com.docker.compose.project=$mname" --format '{{.Names}}' | grep mariadb | head -1)
   branchver=$("$scr_dir"/moodle-version.sh "$mname")
   # shellcheck source=environments/sample.env
   . "$scr_dir/export-env.sh" "$mname"

   # Check that the mariadb service is running
   if [ -z "$container" ]; then
      echo 'The mariadb service must be started to perform the backup. Please start the service.' >&2
      exit 1
   fi

   echo "We will backup the local $mname environment."

   # What label on the backup do they want? (Defaults to "local_branchver_yyyymmdd")
   defaultlabel="local_${branchver}_$(date +"%Y%m%d")"
   label="$2"
   if [ "$label" = "" ]; then
      echo -n "Enter the label to put on the backup [$defaultlabel]: "
      read -r label
      label="${label:-$defaultlabel}"
   fi

   #
   # Prepare target names
   #

   data_path="$env_dir/data"
   data_target="${mname}_${label}_data.tar.bz2"
   src_path="$env_dir/src"
   src_target="${mname}_${label}_src.tar.bz2"
   db_target="${mname}_${label}_db.sql.bz2"

   # Moodle Data
   echo "Copying Moodle data to $data_target..."
   tar cj --no-xattrs \
      --exclude='./trashdir' \
      --exclude='./temp' \
      --exclude='./sessions' \
      --exclude='./localcache' \
      --exclude='./cache' \
      -C "$data_path" . > "$backup_dir/$data_target" &
   # Moodle Source Code
   echo "Copying Moodle source code to $src_target..."
   tar cj --no-xattrs -C "$src_path" . > "$backup_dir/$src_target" &
   # Moodle Database
   echo "Copying database to $db_target..."
   DOCKER_CLI_HINTS=false \
   docker exec -it "$container" mysqldump \
      --user="$DB_USERNAME" \
      --password="$DB_PASSWORD" \
      --single-transaction -C -Q -e --create-options \
      "$DB_NAME" | bzip2 -cq9 > "$backup_dir/$db_target" &

   wait && echo "Local backup of $mname is done!"

done
