#!/bin/bash

# shellcheck disable=SC2155

# Defaults
export MDL_BASE_URL=https://raw.githubusercontent.com/uicpharm/mdl/refs/heads/main
cfg_file=/etc/mdl
mdl_root=/var/moodle
if [[ "$(uname)" == "Darwin" ]]; then
   mdl_root="$HOME/Library/Application Support/moodle"
   cfg_file="$mdl_root/config.ini"
fi
default_backup_dir="$mdl_root/backup"
default_compose_dir="$mdl_root/compose"
default_envs_dir="$mdl_root/environments"
default_versions_file="$mdl_root/versions.txt"
default_versions_source_url=$MDL_BASE_URL/versions.txt
default_versions_source_check_frequency=604800 # 7 days

# Paths
export scr_dir="$(realpath "${0%/*}/../libexec")"
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
mkdir -p "$MDL_BACKUP_DIR"
mkdir -p "$MDL_COMPOSE_DIR"
mkdir -p "$MDL_ENVS_DIR"

# Formatting
export norm=$(tput sgr0)
export ul=$(tput smul)
export rmul=$(tput rmul)
export bold=$(tput bold)
export red=$(tput setaf 1)
export green=$(tput setaf 2)

# Title for the script
export mdl_title=$(cat <<EOF
$red
     ░▒██████████▓░ ░▒█████▓░ ░▒█▒░              ░▓████▓░ ░▒█▓░      ░▒█▒░
     ░▒█▒░░▒█▒░░▒█▒░░▒█▒░░▒█▒░░▒█▒░             ░▒█▒░░▒█▒░░▒█▓░      ░▒█▒░
     ░▒█▒░░▒█▒░░▒█▒░░▒█▒░░▒█▒░░▒█▒░             ░▒█▒░     ░▒█▓░      ░▒█▒░
     ░▒█▒░░▒█▒░░▒█▒░░▒█▒░░▒█▒░░▒█▒░             ░▒█▒░     ░▒█▓░      ░▒█▒░
     ░▒█▒░░▒█▒░░▒█▒░░▒█▒░░▒█▒░░▒█▒░             ░▒█▒░     ░▒█▓░      ░▒█▒░
     ░▒█▒░░▒█▒░░▒█▒░░▒█▒░░▒█▒░░▒█▒░             ░▒█▒░░▒█▒░░▒█▓░      ░▒█▒░
     ░▒█▒░░▒█▒░░▒█▒░░▒█████▓░ ░▒███████▓▒░       ░▓████▓░ ░▒██████▓▒░░▒█▒░
$norm$bold
          A great CLI for managing containerized Moodle environments!
$norm
EOF
)

# Returns the name of the script, trying to factor in whether you called the script
# directly or used the `mdl` script.
function script_name() {
   # shellcheck disable=SC2046
   local -r mdl=$(basename "$(readlink -- $(ps -o command -p $PPID))")
   local sub_cmd=$0
   [[ -n "$mdl" ]] && sub_cmd=${sub_cmd/mdl-/} && echo -n "$mdl "
   basename -s ".${mdl:+sh}" "$sub_cmd"
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

# Receives file path and decompresses it. Can detect bzip2, gzip and xz files. If none of
# those extensions match the filename, it throws an error. After successful decompression,
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
   local cmd
   # Check options
   [[ $* =~ -k || $* =~ --keep ]] && keep=true || keep=false
   # File path is required
   [[ -z $file_path ]] && return 1
   [[ $ext == bz2 ]] && cmd=bzip2
   [[ $ext == gz ]] && cmd=gzip
   [[ $ext == xz ]] && cmd=xz
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

# Asks a question and returns the response. If the user does not provide a response, it
# returns the default value. If no default is provided, it returns an empty string.
function ask() {
   local question=$1
   local default=$2
   echo -n "$question" >&2
   [[ -n $default ]] && echo -n " [$default]" >&2
   echo -n ": " >&2
   read -r response
   echo "${response:-$default}"
}

# Asks a yes/no question and returns 0 for 'yes' and 1 for 'no'. If the user does not
# provide a response, it uses the default value.
function yorn() {
   local question=$1
   local default=${2:-y}
   while true; do
      echo -n "$question " >&2
      [[ $default =~ [Yy] ]] && echo -n "[Y/n]: " >&2 || echo -n "[y/N]: " >&2
      read -r response
      [[ -z $response ]] && response=$default
      response=$(echo "${response:0:1}" | tr '[:upper:]' '[:lower:]')
      if [[ $response == y ]]; then
         return 0
      elif [[ $response == n ]]; then
         return 1
      else
         echo "Please answer 'y' or 'n'." >&2
      fi
   done
}
