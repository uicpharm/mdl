#!/bin/bash

. "${0%/*}/../lib/mdl-common.sh"

display_help() {
   cat <<EOF
Usage: $(script_name) [OPTIONS]

Report information about the Moodle system environment.

Options:
-h, --help         Show this help message and exit.
-q, --quiet        Quiet mode. Suppress normal output.
    --no-title     Do not display the title banner.
EOF
}

[[ $* =~ -h || $* =~ --help ]] && display_help && exit
[[ $* =~ -q || $* =~ --quiet ]] && quiet=true || quiet=false
[[ $* =~ --no-title ]] && display_title=false || display_title=true

requires docker realpath

ok=true
config_status="✅" && [[ ! -f $MDL_CONFIG_FILE ]] && ok=false && config_status="❌"
version_status="✅" && [[ ! -f $MDL_VERSIONS_FILE ]] && ok=false && version_status="❌"
envs_status="✅" && [[ ! -d "$MDL_ENVS_DIR" ]] && ok=false && envs_status="❌"
backup_status="✅" && [[ ! -d "$MDL_BACKUP_DIR" ]] && ok=false && backup_status="❌"
compose_status="✅" && [[ ! -d "$MDL_COMPOSE_DIR" ]] && ok=false && compose_status="❌"
mdl_path=$ul$(which mdl)$rmul
mdl_realpath=$ul$(realpath "$(which mdl)")$rmul
[[ $mdl_path == "$mdl_realpath" ]] && mdl_status="at $mdl_path" || mdl_status="in dev mode at $mdl_realpath"
$quiet || (
   $display_title && mdl_title
   echo "The ${red}mdl$norm CLI is installed $mdl_status."
   echo
   echo "${bold}${ul}Configuration$norm"
   echo "${bold}Config file:$norm $MDL_CONFIG_FILE $config_status"
   echo "${bold}Versions file:$norm $MDL_VERSIONS_FILE $version_status"
   echo "${bold}Versions source URL:$norm $MDL_VERSIONS_SOURCE_URL"
   echo "${bold}Versions update:$norm $MDL_VERSIONS_SOURCE_CHECK_FREQUENCY seconds"
   echo
   echo "${bold}${ul}Directories$norm"
   echo "${bold}Environments:$norm $MDL_ENVS_DIR $envs_status"
   echo "${bold}Backups:$norm $MDL_BACKUP_DIR $backup_status"
   echo "${bold}Compose:$norm $MDL_COMPOSE_DIR $compose_status"
   echo
   echo "${bold}${ul}Environments$norm"
   mnames=$("$scr_dir/mdl-select-env.sh" all)
   if [[ -n $mnames ]]; then
      for mname in $mnames; do
         echo "  - $bold$mname$norm ($MDL_ENVS_DIR/$mname)"
      done
   else
      echo  "No environments found."
   fi
)

# If an environment was not running, exit as an error
[ "$ok" == true ] && exit 0 || exit 1
