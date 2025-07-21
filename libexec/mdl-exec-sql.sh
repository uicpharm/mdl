#!/bin/bash

. "${0%/*}/../lib/mdl-common.sh"

display_help() {
   cat <<EOF
Usage: $(script_name) <ENV> <SQL FILE OR COMMAND>

Executes a SQL script in the container you specify. This makes it easy to execute a SQL
script without needing to make a connection to the MariaDB database with a SQL client.

Options:
-h, --help         Show this help message and exit.

$bold${ul}Examples$norm

Execute a SQL file:
   $bold$(script_name) \$mname /path/to/file.sql$norm

Execute a SQL statement from a string:
   $bold$(script_name) \$mname "select id, username, email from mdl_user limit 5"$norm
EOF
}

[[ $* =~ -h || $* =~ --help ]] && display_help && exit

requires docker

mnames=$("$scr_dir"/mdl-select-env.sh "$1")

for mname in $mnames; do

   sql="$2"
   sql_is_file=false
   [ -f "$sql" ] && sql_is_file=true

   export_env_and_update_config "$mname"

   # Get an existing moodle task on this node
   container="$(docker ps -f "label=com.docker.compose.project=$mname" --format '{{.Names}}' | grep mariadb | head -1)"

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

   # Unset environment variables
   unset_env "$mname"

done
