#!/bin/bash

scr_dir="${0%/*}"
envs_dir="$scr_dir/environments"
mnames=$("$scr_dir"/select-env.sh "$1")

for mname in $mnames; do

   sql="$2"
   sql_is_file=false
   [ -f "$sql" ] && sql_is_file=true

   env_dir="$envs_dir/$mname"
   # shellcheck source=environments/sample.env
   "$scr_dir/touch-env.sh" "$mname" && source "$envs_dir/blank.env" && source "$env_dir/.env"

   # Get an existing moodle task on this node
   container="$(docker ps -q -f name="${mname}_mariadb" | head -1)"

   if [ -n "$container" ]; then
      if $sql_is_file; then
         docker exec -i "$container" mysql -u "$DB_USERNAME" -p"$DB_PASSWORD" "$DB_NAME" "${@:3}" < "$sql"
      else
         docker exec -i "$container" mysql -u "$DB_USERNAME" -p"$DB_PASSWORD" "$DB_NAME" "${@:3}" -e "$sql"
      fi
   else
      echo "Could not find a container running MariaDB for Moodle for $mname!"
      exit 1
   fi

done
