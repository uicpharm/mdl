#!/bin/bash

. "${0%/*}/../lib/mdl-common.sh"
. "${0%/*}/../lib/mdl-formatting.sh"
. "${0%/*}/../lib/mdl-ui.sh"

# Validation
valid_format='pretty json ini'

# Defaults
default_format=pretty

# Declarations
format=$default_format
quiet=false
display_title=true

display_help() {
   cat <<EOF
Usage: $(script_name) [ENV] [FIELD] [OPTIONS]

Report information about the Moodle system environment. If you provide an
environment, it will show information about that specific environment, and if
you provide a field, it will return that specific field. Otherwise, it will
show information about the Moodle system as a whole.

Options:
-h, --help         Show this help message and exit.
-f, --format       Output format (${valid_format// /, }). Default: $default_format
-q, --quiet        Quiet mode. Suppress normal output.
    --no-title     Do not display the title banner.
EOF
}

# Positional parameter #1: Environment
if [[ $1 != -* && -n $1 ]]; then
   mnames=$("$scr_dir/mdl-select-env.sh" "$1")
   shift
fi

# Positional parameter #2: Field
if [[ $1 != -* && -n $1 ]]; then
   field=$1
   shift
fi

# Collect optional arguments.
# shellcheck disable=SC2214
# spellchecker: disable-next-line
while getopts hqf:-: OPT; do
   support_long_options
   case "$OPT" in
      h | help) display_help; exit ;;
      f | format) format=$OPTARG ;;
      q | quiet) quiet=true ;;
      no-title) display_title=false ;;
      \?) echo "${red}Invalid option: -$OPT$norm" >&2 ;;
      *) echo "${red}Some of these options are invalid:$norm $*" >&2; exit 2 ;;
   esac
done
shift $((OPTIND - 1))

# Validation
if [[ ! $valid_format =~ $format ]]; then
   echo "${red}Invalid format specified:$norm $format" >&2
   echo "Valid formats are: ${valid_format// /, }" >&2
   exit 2
fi
if [[ -n $field ]] && [[ $(wc -w <<< "$mnames") -gt 1 ]]; then
   echo "${red}Field can only be specified for a single environment.$norm" >&2
   exit 2
fi

requires "${MDL_CONTAINER_TOOL[0]}" realpath

function make_format () { "make_${format}" "$@"; }
function make_format_array () { "make_${format}_array" "$@"; }
function filter_unset_fields () {
   local out=()
   local field
   for field in "$@"; do
      [[ ${!field+x} ]] && out+=("$field")
   done
   echo "${out[@]}"
}

ok=true
config_status=true && [[ ! -f $MDL_CONFIG_FILE ]] && ok=false && config_status=false
version_status=true && [[ ! -f $MDL_VERSIONS_FILE ]] && ok=false && version_status=false
envs_status=true && [[ ! -d "$MDL_ENVS_DIR" ]] && ok=false && envs_status=false
backup_status=true && [[ ! -d "$MDL_BACKUP_DIR" ]] && ok=false && backup_status=false
compose_status=true && [[ ! -d "$MDL_COMPOSE_DIR" ]] && ok=false && compose_status=false
container_tool_status=true && [[ -z "$("${MDL_CONTAINER_TOOL[0]}" --version 2> /dev/null)" ]] && ok=false && container_tool_status=false
compose_tool_status=true && [[ -z "$("${MDL_COMPOSE_TOOL[0]}" --version 2> /dev/null)" ]] && ok=false && compose_tool_status=false
mdl_path=$(which mdl)
mdl_realpath=$(realpath "$mdl_path")
[[ -L $mdl_path ]] && mdl_status="in dev mode at $ul$mdl_realpath$rmul" || mdl_status="at $ul$mdl_path$rmul"

# If quiet, just exit with status of the system configuration
$quiet && { $ok && exit 0 || exit 1; }

# If no mnames provides, display SYSTEM INFORMATION:
if [[ -z $mnames ]]; then
   read -r -a mnames_array <<< "$("$scr_dir/mdl-select-env.sh" all)"
   fields=(
      ok mdl_path mdl_realpath config_status version_status envs_status backup_status compose_status env_names \
      compose_tool compose_tool_status container_tool container_tool_status \
      MDL_CONFIG_FILE MDL_VERSIONS_FILE MDL_VERSIONS_SOURCE_URL MDL_VERSIONS_SOURCE_CHECK_FREQUENCY MDL_ENVS_DIR \
      MDL_BACKUP_DIR MDL_COMPOSE_DIR
   )
   if [[ $format == pretty ]]; then
      $display_title && mdl_title
      echo "The ${red}mdl$norm CLI is installed $mdl_status."
      echo
      pretty_line 'Configuration'
      pretty_line 'Config file' "$MDL_CONFIG_FILE" $config_status
      pretty_line 'Versions file' "$MDL_VERSIONS_FILE" $version_status
      pretty_line 'Versions source URL' "$MDL_VERSIONS_SOURCE_URL"
      pretty_line 'Versions update' "$MDL_VERSIONS_SOURCE_CHECK_FREQUENCY seconds"
      pretty_line 'Container tool' "${MDL_CONTAINER_TOOL[*]}" $container_tool_status
      pretty_line 'Compose tool' "${MDL_COMPOSE_TOOL[*]}" $compose_tool_status
      echo
      pretty_line 'Directories'
      pretty_line 'Environments' "$MDL_ENVS_DIR" $envs_status
      pretty_line 'Backups' "$MDL_BACKUP_DIR" $backup_status
      pretty_line 'Compose' "$MDL_COMPOSE_DIR" $compose_status
      echo
      pretty_line 'Environments'
      if [[ ${#mnames_array[@]} -gt 0 ]]; then
         for mname in "${mnames_array[@]}"; do
            echo "  - $bold$mname$norm ($MDL_ENVS_DIR/$mname)"
         done
      else
         echo "No environments found."
      fi
   else
      # shellcheck disable=SC2034
      env_names=$(make_format_array "${mnames_array[@]}")
      # shellcheck disable=SC2034
      container_tool=$(make_format_array "${MDL_CONTAINER_TOOL[@]}")
      # shellcheck disable=SC2034
      compose_tool=$(make_format_array "${MDL_COMPOSE_TOOL[@]}")
      make_format "${fields[@]}"
   fi
   exit
fi

# If field is provided, display JUST ONE FIELD:
if [[ -n $field ]]; then
   # We know mnames is one environment because we won't allow multiple when field is specified
   mname=$mnames
   export_env "$mname"
   if [[ $format == pretty ]]; then
      echo "${!field}"
   else
      make_format "$field"
   fi
   exit
fi

# Otherwise, display ALL INFORMATION FOR THE SELECTED ENVIRONMENT(S):
[[ $format == pretty ]] && $display_title && mdl_title
[[ $format == json ]] && echo "["
first=true
for mname in $mnames; do
   # ENVIRONMENT INFORMATION
   fields=(
      MOODLE_HOST WWWROOT MOODLE_PORT \
      MOODLE_IMAGE MARIADB_IMAGE \
      DB_TYPE DB_HOST DATA_ROOT DB_NAME ROOT_PASSWORD DB_USERNAME DB_PASSWORD \
      SOURCE_HOST SOURCE_DATA_PATH SOURCE_SRC_PATH SOURCE_DB_NAME SOURCE_DB_USERNAME SOURCE_DB_PASSWORD \
      BOX_CLIENT_ID BOX_CLIENT_SECRET BOX_REDIRECT_URI BOX_FOLDER_ID \
      mname running env_path custom_path db_vol_name data_vol_name src_vol_name \
      env_status custom_status db_status data_status src_status
   )
   # Standard configs
   export_env "$mname"
   # Custom configs
   custom_fields=()
   while IFS= read -r line; do
      [[ $line =~ ^#.*$ || -z $line ]] && continue
      field=${line%%=*}
      # If field is not in fields array and looks like a valid env var (uppercase only), add to custom_fields
      [[ " ${fields[*]} " != *" $field "* && $field =~ ^[A-Z_0-9]+$ ]] && custom_fields+=("$field")
   done < "$MDL_ENVS_DIR/$mname/.env"
   # Additional calculated fields
   . "$scr_dir/mdl-calc-images.sh" "$mname"
   env_path="$MDL_ENVS_DIR/$mname/.env"
   custom_path="$MDL_ENVS_DIR/$mname/custom-config.sh"
   vols=$(container_tool volume ls -q --filter "label=com.docker.compose.project=$mname")
   db_vol_name=$(grep db <<< "$vols")
   data_vol_name=$(grep data <<< "$vols")
   src_vol_name=$(grep src <<< "$vols")
   running=false && [[ -n $(container_tool ps -q -f name="$mname") ]] && running=true
   running_string="${red}not running$norm" && $running && running_string="${green}running$norm"
   env_status=false && [ -f "$env_path" ] && env_status=true
   custom_status=false && [ -f "$custom_path" ] && custom_status=true
   db_status=false && [ -n "$db_vol_name" ] && db_status=true
   data_status=false && [ -n "$data_vol_name" ] && data_status=true
   src_status=false && [ -n "$src_vol_name" ] && src_status=true
   if [[ $format == pretty ]]; then
      pretty_line "${red}Environment" "$bold$mname$norm"
      echo
      pretty_line 'Status' "$running_string" "$running"
      echo
      pretty_line 'Moodle Configuration'
      [[ -n $MOODLE_PORT ]] && pretty_line 'Port' "$MOODLE_PORT"
      pretty_line 'Host' "$MOODLE_HOST"
      pretty_line 'WWW Root' "$ul$WWWROOT$rmul"
      echo
      pretty_line 'Database Configuration'
      [[ -n $DB_TYPE ]] && pretty_line 'Type' "$DB_TYPE"
      [[ -n $DB_HOST ]] && pretty_line 'Host' "$DB_HOST"
      [[ -n $DATA_ROOT ]] && pretty_line 'Data Root' "$DATA_ROOT"
      pretty_line 'Name' "$DB_NAME"
      pretty_line 'Root password' "$ROOT_PASSWORD"
      pretty_line 'Username' "$DB_USERNAME"
      pretty_line 'Password' "$DB_PASSWORD"
      echo
      pretty_line 'Paths and Volumes'
      pretty_line 'Environment file' "$env_path" "$env_status"
      pretty_line 'Custom config file' "$custom_path" "$custom_status"
      pretty_line 'Database volume' "${db_vol_name:-${red}missing$norm}" "$db_status"
      pretty_line 'Data volume' "${data_vol_name:-${red}missing$norm}" "$data_status"
      pretty_line 'Source volume' "${src_vol_name:-${red}missing$norm}" "$src_status"
      echo
      if [[ -n $SOURCE_HOST || -n $SOURCE_DATA_PATH || -n $SOURCE_SRC_PATH || -n $SOURCE_DB_NAME || -n $SOURCE_DB_USERNAME || -n $SOURCE_DB_PASSWORD ]]; then
         pretty_line 'Remote Source Configuration'
         [[ -n $SOURCE_HOST ]] && pretty_line 'Host' "$SOURCE_HOST"
         [[ -n $SOURCE_DATA_PATH ]] && pretty_line 'Data Path' "$SOURCE_DATA_PATH"
         [[ -n $SOURCE_SRC_PATH ]] && pretty_line 'Source Path' "$SOURCE_SRC_PATH"
         [[ -n $SOURCE_DB_NAME ]] && pretty_line 'Database Name' "$SOURCE_DB_NAME"
         [[ -n $SOURCE_DB_USERNAME ]] && pretty_line 'Database Username' "$SOURCE_DB_USERNAME"
         [[ -n $SOURCE_DB_PASSWORD ]] && pretty_line 'Database Password' "$SOURCE_DB_PASSWORD"
         echo
      fi
      if [[ -n $BOX_CLIENT_ID || -n $BOX_CLIENT_SECRET || -n $BOX_REDIRECT_URI || -n $BOX_FOLDER_ID ]]; then
         pretty_line 'Box Configuration'
         [[ -n $BOX_CLIENT_ID ]] && pretty_line 'Client ID' "$BOX_CLIENT_ID"
         [[ -n $BOX_CLIENT_SECRET ]] && pretty_line 'Client Secret' "$BOX_CLIENT_SECRET"
         [[ -n $BOX_REDIRECT_URI ]] && pretty_line 'Redirect URI' "$BOX_REDIRECT_URI"
         [[ -n $BOX_FOLDER_ID ]] && pretty_line 'Folder ID' "$BOX_FOLDER_ID"
         echo
      fi
      if [[ ${#custom_fields[@]} -gt 0 ]]; then
         pretty_line 'Custom Fields'
         for field in "${custom_fields[@]}"; do
            pretty_line "$field" "${!field}"
         done
         echo
      fi
   else
      if [[ $format == json ]]; then $first && first=false || echo ","; fi
      if [[ $format == ini ]]; then $first && first=false || echo; echo "[${mname}]"; fi
      read -r -a fields <<< "$(filter_unset_fields "${fields[@]}" "${custom_fields[@]}")"
      make_format "${fields[@]}"
   fi
   unset_env "$mname"
done
[[ $format == json ]] && echo "]"
