#!/bin/bash

scr_dir="${0%/*}"
envs_dir="$scr_dir/environments"
norm=$(tput sgr0)
ul=$(tput smul)
bold=$(tput bold)

arch=$(uname)
docker_exists=$(grep -w 1001 /etc/passwd)
user=''
identity=''

# Parse command-line options and their arguments
while getopts ":i:u:" opt; do
   case "$opt" in
      i) identity="$OPTARG" ;;
      u) user="$OPTARG" ;;
      \?) echo "Invalid option: -$OPTARG" >&2 ;;
      :) echo "Option -$OPTARG requires an argument." >&2
         exit 1
         ;;
   esac
done
shift $((OPTIND-1))

# SSH settings. Use calling user's ssh configs if they exist, not root's (when using sudo).
ssh_params=()
[ -f "$HOME/.ssh/config" ] && ssh_params=("-F" "$HOME/.ssh/config" "${ssh_params[@]}")
[ -n "$identity" ] && ssh_params=("-i" "$identity" "${ssh_params[@]}")

mnames=$("$scr_dir"/select-env.sh "$1")

for mname in $mnames; do

   env_dir="$envs_dir/$mname"
   # shellcheck source=environments/sample.env
   "$scr_dir/touch-env.sh" "$mname" && source "$envs_dir/blank.env" && source "$env_dir/.env"
   defaultsrv='mymoodle.sample.dev'

   srv="$REMOTE_SERVER"
   data_path="$REMOTE_DATA_PATH"
   src_path="$REMOTE_SRC_PATH"
   db_name="$REMOTE_DB_NAME"
   db_username="$REMOTE_DB_USERNAME"
   db_password="$REMOTE_DB_PASSWORD"

   echo "$bold"
   echo "Syncing $ul$mname$norm$bold from remote server $ul$srv"
   echo "$norm"

   #
   # Collect required parameters, if they aren't in env file
   #

   # Server
   if [ -z "$srv" ]; then
      echo -n "Server address [$defaultsrv]: "
      read -r srv
      srv="${srv:-$defaultsrv}"
   fi
   # Moodle Data
   if [ -z "$data_path" ]; then
      echo -n "Path to $mname Moodle data: "
      read -r data_path
   fi
   # Moodle Source Code
   if [ -z "$src_path" ]; then
      echo -n "Path to $mname Moodle source code: "
      read -r src_path
   fi
   # Moodle Database
   if [[ -z "$db_name" || -z "$db_username" || -z "$db_password" ]]; then
      default_db_name="${REMOTE_DB_NAME:-$DB_NAME}"
      default_db_username="${REMOTE_DB_USERNAME:-$DB_USERNAME}"
      default_db_password="${REMOTE_DB_PASSWORD:-$DB_PASSWORD}"
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

   # Sanitization
   [[ "$data_path" != */ ]] && data_path="$data_path/"
   [[ "$src_path" != */ ]] && src_path="$src_path/"
   # If we have a custom user, provide it. Otherwise don't include it to use default. This is
   # important because perhaps the user is specified in the ssh configs.
   [ -n "$user" ] && user_at_srv="$user@$srv" || user_at_srv="$srv"

   # Docker environment paths
   data_target="$env_dir/data"
   src_target="$env_dir/src"
   db_target="$env_dir/db"
   sql_target="$env_dir/backup.sql"

   # Stop the services if they're running
   "$scr_dir/stop.sh" "$mname"

   #
   # If the following `rsync` and `ssh` calls are ran while in sudo, the user will be root. By
   # prepping the ssh configurations above to provide identity, user, and ssh configuration files,
   # we ensure we're using the credentials we want while still using the calling user's configs
   # when they're available.
   #

   # Moodle Data
   echo "Syncing Moodle data..."
   rsync -aLq --delete --progress \
      -e "ssh ${ssh_params[*]}" \
      --rsync-path="sudo rsync" \
      --exclude='/trashdir/' \
      --exclude='/temp/' \
      --exclude='/sessions/' \
      --exclude='/localcache/' \
      --exclude='/cache/' \
      "$user_at_srv:$data_path" "$data_target" && \
   [ "$arch" = "Linux" ] && chown -R 1 "$data_target"

   # Moodle Source Code
   echo "Syncing Moodle source code..."
   rsync -aLq --delete --progress \
      -e "ssh ${ssh_params[*]}" \
      --rsync-path="sudo rsync" \
      "$user_at_srv:$src_path" "$src_target" && \
   [ "$arch" = "Linux" ] && chown -R 1 "$src_target"

   # Moodle Database
   echo "Syncing database..."
   # To securely send the password via script on an open server, we write a temp conf file
   # with username/password, and then delete it when done.
   # shellcheck disable=SC2029
   if ! ssh "${ssh_params[@]}" "$user_at_srv" "\
      printf $'[mysqldump]\nuser=$db_username\npassword=\'$db_password\'\n'>$db_name.cnf && \
      sudo mysqldump --defaults-file=$db_name.cnf --single-transaction -h localhost -C -Q -e --create-options $db_name && \
      rm $db_name.cnf
   " > "$sql_target"; then
      # Remove the backup file since backup failed
      rm "$sql_target"
   fi && \
   rm -Rf "$db_target" && \
   mkdir -p "$db_target" && [ "$arch" = "Linux" ] && chown 1001 "$db_target" && \
   [ -n "$docker_exists" ] && [ "$arch" = "Linux" ] && chown 1001 "$sql_target"

   # Update Moodle config
   "$scr_dir/update-config.sh" "$mname"

   echo "Remote sync of $mname is done!"

done
