#!/bin/bash

# shellcheck disable=SC2155

# Defaults
export MDL_GIT_IMAGE=docker.io/alpine/git:v2.49.1
export MDL_SHELL_IMAGE=docker.io/busybox:1
export MDL_SOCAT_IMAGE=docker.io/alpine/socat:1.8.0.3
export MDL_BASE_URL=https://raw.githubusercontent.com/uicpharm/mdl/refs/heads/main
if [[ $EUID -eq 0 ]]; then
   cfg_file=/etc/mdl.conf
   mdl_root=/var/moodle
else
   cfg_file=$HOME/.moodle/mdl.conf
   mdl_root=$HOME/.moodle
fi
default_backup_dir="$mdl_root/backup"
default_compose_dir="$mdl_root/compose"
default_envs_dir="$mdl_root/environments"
default_versions_file="$mdl_root/versions.txt"
default_versions_source_url=$MDL_BASE_URL/versions.txt
default_versions_source_check_frequency=604800 # 7 days
default_container_tool=(docker)
default_compose_tool=(docker compose)

# Paths
export scr_dir=${scr_dir:-$(realpath "$(dirname "$(readlink -f "$0")")/../libexec")}
export MDL_ROOT=$mdl_root
export MDL_CONFIG_FILE=$cfg_file
# shellcheck source=/dev/null
[[ -f $MDL_CONFIG_FILE ]] && . "$MDL_CONFIG_FILE"
export MDL_BACKUP_DIR="${MDL_BACKUP_DIR:-$default_backup_dir}"
export MDL_COMPOSE_DIR="${MDL_COMPOSE_DIR:-$default_compose_dir}"
export MDL_ENVS_DIR="${MDL_ENVS_DIR:-$default_envs_dir}"
export MDL_VERSIONS_FILE="${MDL_VERSIONS_FILE:-$default_versions_file}"
export MDL_VERSIONS_SOURCE_URL="${MDL_VERSIONS_SOURCE_URL:-$default_versions_source_url}"
export MDL_VERSIONS_SOURCE_CHECK_FREQUENCY="${MDL_VERSIONS_SOURCE_CHECK_FREQUENCY:-$default_versions_source_check_frequency}"
[[ ${#MDL_CONTAINER_TOOL} -eq 0 ]] && export MDL_CONTAINER_TOOL=("${default_container_tool[@]}")
[[ ${#MDL_COMPOSE_TOOL} -eq 0 ]] && export MDL_COMPOSE_TOOL=("${default_compose_tool[@]}")

# Formatting
export norm=$(tput sgr0)
export ul=$(tput smul)
export rmul=$(tput rmul)
export bold=$(tput bold)
export red=$(tput setaf 1)
export green=$(tput setaf 2)
export yellow=$(tput setaf 3)

# Container handling
function compose_tool() { "${MDL_COMPOSE_TOOL[@]}" "$@"; }
function container_tool() { "${MDL_CONTAINER_TOOL[@]}" "$@"; }

# Throws an error if the provided command(s) are not available on the system
function requires() {
   local ok=true
   for cmd in "$@"; do
      if ! command -v "$cmd" &>/dev/null; then
         echo "${red}${bold}This command requires $ul$cmd$rmul to work.$norm" >&2
         ok=false
      elif [[ $cmd =~ docker || $cmd =~ podman ]]; then
         root_cmd=${cmd%-*}
         if ! "$root_cmd" info &>/dev/null; then
            echo "${red}${bold}You need to start $root_cmd before you can continue.$norm" >&2
            exit 1
         fi
      fi
   done
   $ok || exit 1
}

# Returns the name of the script, trying to factor in whether you called the script
# directly or used the `mdl` script.
function script_name() {
   local -r script_basename=$(basename -s .sh "$0")
   echo "${script_basename/-/ }"
}

# Adjusts the results from `getopts` to support long options. It will only support the
# format `--long-option=value` or `--long-option`, not `--long-option value`.
function support_long_options() {
   # Ref: https://stackoverflow.com/a/28466267/519360
   if [ "$OPT" = "-" ]; then
      OPT="${OPTARG%%=*}"       # extract long option name
      OPTARG="${OPTARG#"$OPT"}" # extract long option argument (may be empty)
      OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
   fi
}

function calc_compression_tool() {
   local ext=${1##*.}
   local cmd
   [[ $ext == bz2 ]] && cmd=bzip2 && command -v pbzip2 &>/dev/null && cmd=pbzip2
   [[ $ext == gz ]] && cmd=gzip && command -v pigz &>/dev/null && cmd=pigz
   [[ $ext == xz ]] && cmd=xz && command -v pixz &>/dev/null && cmd=pixz
   echo "$cmd"
}

# Receives file path and decompresses it. Can detect bzip2, gzip and xz files. If none of
# those extensions match the filename, it throws an error. It will always try to use the
# parallel processing version of the command if available. After successful decompression,
# the original file is deleted unless you specify `--keep`.
#
# Parameters:
# - `file_path`: Path to file to be decompressed. Required.
# - `out`: Path to output file. Defaults to file path without the compression extension.
# - `--keep` or `-k`: Do not delete the original file.
function decompress() {
   local file_path=$1
   local out=$2
   local ext=${file_path##*.}
   local cmd=$(calc_compression_tool "$ext")
   # Check options
   [[ $* =~ -k || $* =~ --keep ]] && keep=true || keep=false
   # File path is required
   [[ -z $file_path ]] && return 1
   if [[ -n $cmd ]]; then
      # If they didn't provide an explicit output path, use file path sans extension
      [[ -z $out ]] && out=${file_path%".$ext"}
      # Attempt decompression. If successful, remove the original and return output path
      if $cmd -d -c "$file_path" > "$out"; then
         $keep || rm -f "$file_path"
         echo "$out"
         return 0
      fi
      return 3
   fi
   # If we got here, the file is not compressed. Throw an error.
   return 2
}

# Function that uses awk to safely extract label from filename. Expects to receive
# filename from pipe, such as: `echo $mname | extract_label <MNAME> <TYPE>`
function extract_label() {
   cat | awk -v type="$2" -v mname="$1" '
      # Filter essentially looks for: /_<TYPE>\./ for example type "src" matches "_src."
      /_'"$2"'\./ {
         # Remove leading "<MNAME>_", so mname "moodle" matches "moodle_" at start of name.
         sub("^" mname "_", "");
         # Remove ending "_<TYPE>.*", so type "src" matches "_src.tar", "_src.tar.bz2", etc at end of name.
         sub("_" type "\\..*$", "");
         print $0
      }
   '
}

# Used to clear all known vars to proactively avoid data leaks.
# Usage: unset_env <ENV>
function unset_env() {
   local -r env_dir="$MDL_ENVS_DIR/$1"
   local -r -a variables=(
      ROOT_PASSWORD DB_NAME DB_USERNAME DB_PASSWORD MOODLE_HOST WWWROOT
      SOURCE_HOST SOURCE_DATA_PATH SOURCE_SRC_PATH SOURCE_DB_NAME SOURCE_DB_USERNAME SOURCE_DB_PASSWORD
      BOX_CLIENT_ID BOX_CLIENT_SECRET BOX_REDIRECT_URI BOX_FOLDER_ID
   )
   for var in "${variables[@]}"; do
      unset "$var"
   done
   # shellcheck disable=SC2046
   unset $(grep -E '^[A-Z_0-9]+=' "$env_dir/.env" | cut -d= -f1 | xargs)
}

# Exports all .env variables.
# Usage: export_env <ENV>
function export_env() {
   local -r env_dir="$MDL_ENVS_DIR/$1"
   # We touch the .env file before we look at it.
   "$scr_dir/mdl-touch-env.sh" "$1"
   # shellcheck disable=SC2046
   export $(grep -E '^[A-Z_0-9]+=' "$env_dir/.env" | xargs)
   export mname=$1
}

# Updates config.php with the environment variables. Assumes that export_env has already been run.
# Usage: update_config <ENV>
function update_config() {
   local -r env_dir="$MDL_ENVS_DIR/$1"

   # Get the Moodle container and its mount paths for this environment
   local -r container="$(container_tool ps -a -f "label=com.docker.compose.project=$1" --format '{{.Names}}' | grep moodle | head -1)"
   local -r data_path=${container:+$(container_tool inspect "$container" | jq -r '.[] .Mounts[] | select(.Name != null and (.Name | contains("data"))) | .Destination')}

   # Get desired wwwroot value
   if [ -z "$WWWROOT" ]; then
      local defaultwwwroot=''
      # Determine default wwwroot from existing config if possible (container must be running)
      if [[ -n $container ]]; then
         local -r src_path=${container:+$(container_tool inspect "$container" | jq -r '.[] .Mounts[] | select(.Name != null and (.Name | contains("src"))) | .Destination')}
         if [[ -n $src_path ]]; then
            defaultwwwroot=$(container_tool exec -t "$container" php -r "define('CLI_SCRIPT', true); require '$src_path/config.php'; echo \$CFG->wwwroot;")
         fi
      fi
      local altwwwroot1="http://$HOSTNAME"
      [ "$defaultwwwroot" = "$altwwwroot1" ] && altwwwroot1=''
      local altwwwroot2="http://$MOODLE_HOST"
      [ "$defaultwwwroot" = "$altwwwroot2" ] && altwwwroot2=''
      echo 'You can avoid this prompt by setting WWWROOT in your .env file.'
      PS3="Select a desired wwwroot value or type your own: "
      select WWWROOT in $defaultwwwroot $altwwwroot1 $altwwwroot2; do
         WWWROOT="${WWWROOT:-$REPLY}"
         break
      done
   fi

   local cmd="
      env_dir=/env
      env_config_file=/src/config.php
      source /env/.env
      WWWROOT=$WWWROOT
   "
   cmd="$cmd $(cat <<'EOF'
      replace_config_value() {
         local content="$1"
         [[ -t 0 ]] && shift || content="$(cat)"
         local key="$1"
         local val="$2"
         echo "$content" | sed -E "s|(\\\$CFG->${key}[[:space:]]*=[[:space:]]*'?)[^';]*('?;)|\1${val}\2|g"
      }

      # Replace values in config
      if [[ -f "$env_config_file" ]]; then
         # Standard updates
         config_content=$(
            sed -E "/'dbport'/ s/> .*,/> 3306,/" "$env_config_file" |
            replace_config_value dbtype "${DB_TYPE:-mariadb}" |
            replace_config_value dbhost "${DB_HOST:-mariadb}" |
            replace_config_value dbname "$DB_NAME" |
            replace_config_value dbuser "$DB_USERNAME" |
            replace_config_value dbpass "$DB_PASSWORD" |
            replace_config_value wwwroot "$WWWROOT"
         )
         if [[ -n "$DATA_ROOT" || -n "$data_path" ]]; then
            config_content=$(replace_config_value "$config_content" dataroot "${DATA_ROOT:-$data_path}")
         fi
         # Run custom updates if provided
         custom_script="$env_dir/custom-config.sh"
         [[ -f "$custom_script" ]] && config_content=$(. "$custom_script" "$config_content")
         # Write new contents to config file
         [[ -n "$config_content" ]] && echo "$config_content" > "$env_config_file"
      fi
EOF
   )"

   container_tool volume inspect "${1}_src" &> /dev/null && \
   container_tool run --rm -t --name "${1}_worker_update_config" \
      -v "$env_dir":/env:Z,ro \
      -v "${1}_src":/src \
      -e data_path="$data_path" \
      "$MDL_SHELL_IMAGE" sh -c "$cmd"
}

function export_env_and_update_config() {
   export_env "$@"
   update_config "$@"
}
