#!/bin/bash

. "${0%/*}/../lib/mdl-common.sh"

display_help() {
   cat <<EOF
Usage: $(script_name) <ENV>

Report the status of Moodle environment(s). Are they running? If so, what are their
service names and IDs and data paths? What backup sets do they have?

Options:
-h, --help         Show this help message and exit.
-b, --box          Include Box in the list of backup sets
-q, --quiet        Quiet mode. Suppress normal output.
EOF
}

[[ $* =~ -h || $* =~ --help ]] && display_help && exit
[[ $* =~ -b || $* =~ --box ]] && mdl_ls_params=(-b) || mdl_ls_params=()
[[ $* =~ -q || $* =~ --quiet ]] && quiet=true || quiet=false

requires "${MDL_CONTAINER_TOOL[0]}" "${MDL_COMPOSE_TOOL[0]}" grep

mnames=$("$scr_dir/mdl-select-env.sh" "${1:-all}")
success=true

for mname in $mnames; do

   running="$(container_tool ps -q -f name="$mname")"
   env_path="$MDL_ENVS_DIR/$mname/.env"
   custom_path="$MDL_ENVS_DIR/$mname/custom-config.sh"
   vols=$(container_tool volume ls -q --filter "label=com.docker.compose.project=$mname")
   db_vol_name=$(grep db <<< "$vols")
   data_vol_name=$(grep data <<< "$vols")
   src_vol_name=$(grep src <<< "$vols")
   compose_path=$("$scr_dir/mdl-calc-compose-path.sh" "$mname")

   $quiet || echo "${ul}Environment: $bold$mname$norm"
   # Status
   if [ -n "$running" ]; then
      $quiet || echo "Status: ${green}running${norm}"
   else
      $quiet || echo "Status: ${red}not running${norm}"
      success=false
   fi
   $quiet || (
      # Path info
      [ -f "$env_path" ] && env_status="${green}exists" || env_status="${red}missing"
      [ -f "$custom_path" ] && custom_status="${green}exists" || custom_status="${red}missing/optional"
      [ -n "$db_vol_name" ] && db_status="${green}exists" || db_status="${red}missing"
      [ -n "$data_vol_name" ] && data_status="${green}exists" || data_status="${red}missing"
      [ -n "$src_vol_name" ] && src_status="${green}exists" || src_status="${red}missing"
      # If volumes were not found, set the name to what it should've been
      [ -z "$db_vol_name" ] && db_vol_name="${mname}_db"
      [ -z "$data_vol_name" ] && data_vol_name="${mname}_data"
      [ -z "$src_vol_name" ] && src_vol_name="${mname}_src"
      echo "Paths:"
      echo "  - $env_path ($env_status$norm)"
      echo "  - $custom_path ($custom_status$norm)"
      echo "  - $db_vol_name ($db_status$norm)"
      echo "  - $data_vol_name ($data_status$norm)"
      echo "  - $src_vol_name ($src_status$norm)"
      # List Backups
      "$scr_dir/mdl-ls.sh" "$mname" "${mdl_ls_params[@]}"
      # If running, the services list
      if [ -n "$running" ]; then
         echo
         . "$scr_dir/mdl-calc-images.sh" "$mname"
         export_env "$mname"
         compose_tool -p "$mname" -f "$compose_path" ps 2>/dev/null
         unset_env "$mname"
      fi
      echo
   )

done

# If an environment was not running, exit as an error
$success && exit 0 || exit 1
