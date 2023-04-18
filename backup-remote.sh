#!/bin/bash

scr_dir="${0%/*}"
envs_dir="$scr_dir/environments"
backup_dir="$scr_dir/backup"
mnames=$("$scr_dir"/select-env.sh "$1")
norm="$(tput sgr0)"
ul="$(tput smul)"
bold="$(tput bold)"

for mname in $mnames; do

   env_dir="$envs_dir/$mname"
   # shellcheck source=environments/sample.env
   "$scr_dir"/touch-env.sh "$mname" && source "$env_dir"/.env
   defaultsrv='mymoodle.sample.dev'
   srv="$3"

   echo
   echo "${bold}Backing up ${ul}${mname}${norm}"
   echo

   # What label on the backup do they want? (Defaults to today's date yyyymmdd)
   defaultlabel=$(date +"%Y%m%d")
   label="$2"
   if [ "$label" = "" ]; then
      echo -n "Enter the label to put on the backup [$defaultlabel]: "
      read -r label
      label="${label:-$defaultlabel}"
   fi

   #
   # Status check (What do we have, what do we need)
   #

   data_status="ready"
   data_target="${mname}_${label}_data.tar.bz2"
   if [ -f "$backup_dir/$data_target" ]; then
      echo "I will use existing $data_target file."
   else
      echo "I will create a new $data_target file."
      data_status="need"
   fi

   src_status="ready"
   src_target="${mname}_${label}_src.tar.bz2"
   if [ -f "$backup_dir/$src_target" ]; then
      echo "I will use existing $src_target file."
   else
      echo "I will create a new $src_target file."
      src_status="need"
   fi

   db_status="ready"
   db_target="${mname}_${label}_db.sql.bz2"
   if [ -f "$backup_dir/$db_target" ]; then
      echo "I will use existing $db_target file."
   else
      echo "I will create a new $db_target file."
      db_status="need"
   fi

   #
   # If we need anything, collect it now.
   #

   if [[ "$data_status" == "need" || "$src_status" == "need" || "$db_status" == "need" ]]; then
      if [ "$srv" = "" ]; then
         echo -n "Server address [$defaultsrv]: "
         read -r srv
         srv="${srv:-$defaultsrv}"
      fi
      echo "Will save missing backup data for $mname from $srv."
      mkdir -p backup
      # Moodle Data
      if [ "$data_status" = "need" ]; then
         echo -n "Path to $mname Moodle data: "
         read -r data_path
      fi
      # Moodle Source Code
      if [ "$src_status" = "need" ]; then
         echo -n "Path to $mname Moodle source code: "
         read -r src_path
      fi
      # Moodle Database
      if [ "$db_status" = "need" ]; then
         default_db_name="$DB_NAME"
         default_db_username="$DB_USERNAME"
         default_db_password="$DB_PASSWORD"
         echo -n "Database name [$default_db_name]: "
         read -r db_name
         db_name="${db_name:-$default_db_name}"
         echo -n "Database user [$default_db_username]: "
         read -r db_username
         db_username="${db_username:-$default_db_username}"
         echo -n "Password [hit enter to use password in env file]: "
         read -r -s db_password
         db_password="${db_password:-$default_db_password}"
         echo
      fi
      # Run everything that needs to run
      if [ "$data_status" = "need" ]; then
         echo "Copying Moodle data to $data_target..."
         if ! ssh "$srv" sudo tar cj --no-xattrs \
            --exclude='./trashdir' \
            --exclude='./temp' \
            --exclude='./sessions' \
            --exclude='./localcache' \
            --exclude='./cache' \
            -C "$data_path" . > "$backup_dir/$data_target";
         then
            # Remove the backup file since backup failed
            rm "$backup_dir/$data_target"
         fi &
      fi
      if [ "$src_status" = "need" ]; then
         echo "Copying Moodle source code to $src_target..."
         if ! ssh "$srv" sudo tar cj --no-xattrs -C "$src_path" . > "$backup_dir/$src_target"; then
            # Remove the backup file since backup failed
            rm "$backup_dir/$src_target"
         fi &
      fi
      if [ "$db_status" = "need" ]; then
         echo "Copying database to $db_target..."
         # To securely send the password via script on an open server, we write a temp conf file
         # with username/password, and then delete it when done.
         # shellcheck disable=SC2029
         if ! ssh "$srv" "\
            printf $'[mysqldump]\nuser=$db_username\npassword=\'$db_password\'\n'>$db_target.cnf && \
            sudo mysqldump --defaults-file=$db_target.cnf --single-transaction -h localhost -C -Q -e --create-options $db_name | bzip2 -cq9 && \
            rm $db_target.cnf
         " > "$backup_dir/$db_target"; then
            # Remove the backup file since backup failed
            rm "$backup_dir/$db_target"
         fi &
      fi
      wait && echo "Remote backup of $mname is done!"
   else
      echo "We have existing $data_target, $src_target, and $db_target files!"
   fi

done
