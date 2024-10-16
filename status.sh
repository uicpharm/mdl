#!/bin/bash

. "${0%/*}/util/common.sh"

display_help() {
   cat <<EOF
Usage: $(script_name) <ENV>

Report the status of Moodle environment(s). Are they running? If so, what are their
service names and IDs and data paths? What backup sets do they have?

Options:
-h, --help         Show this help message and exit.
-q, --quiet        Quiet mode. Suppress normal output.
EOF
}

[[ $* =~ -h || $* =~ --help ]] && display_help && exit
[[ $* =~ -q || $* =~ --quiet ]] && quiet=true || quiet=false

mnames=$("$scr_dir/select-env.sh" "${1:-all}")
ok=true

for mname in $mnames; do

   running="$(docker ps -q -f name="$mname")"
   data_dir="$envs_dir/$mname/data"
   src_dir="$envs_dir/$mname/src"
   sql_path="$envs_dir/$mname/backup.sql"
   db_vol_name=$(docker volume ls -q --filter "label=com.docker.compose.project=$mname" | grep db)
   docker_compose_path=$("$scr_dir/calc-docker-compose-path.sh" "$mname")

   $quiet || echo "${ul}Environment: $bold$mname$norm"
   # Status
   if [ -n "$running" ]; then
      $quiet || echo "Status: ${green}running${norm}"
   else
      $quiet || echo "Status: ${red}not running${norm}"
      ok=false
   fi
   $quiet || (
      # Path info
      [ -d "$data_dir" ] && data_status="${green}exists" || data_status="${red}missing"
      [ -d "$src_dir" ] && src_status="${green}exists" || src_status="${red}missing"
      [ -f "$sql_path" ] && sql_status="${green}exists" || sql_status="${red}missing"
      [ -n "$db_vol_name" ] && db_status="${green}exists" || db_status="${red}missing"
      # If db volume was not found, set the name to what it should've been
      [ -z "$db_vol_name" ] && db_vol_name="${mname}_db"
      echo "Paths:"
      echo "  - $data_dir ($data_status$norm)"
      echo "  - $src_dir ($src_status$norm)"
      echo "  - $sql_path ($sql_status$norm)"
      echo "  - $db_vol_name ($db_status$norm)"
      # List Backups
      "$scr_dir/ls.sh" "$mname"
      # If running, the services list
      if [ -n "$running" ]; then
         echo
         . "$scr_dir/export-env.sh" "$mname"
         (cd "$scr_dir" && docker-compose -f "$docker_compose_path" ps 2>/dev/null)
      fi
      echo
   )

done

# If an environment was not running, exit as an error
[ "$ok" == true ] && exit 0 || exit 1
