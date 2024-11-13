#!/bin/bash

# shellcheck disable=SC2155

# Paths
export scr_dir="$(realpath "${0%/*}")"
export backup_dir="$scr_dir/backup"
export envs_dir="$scr_dir/environments"

# Formatting
export norm=$(tput sgr0)
export ul=$(tput smul)
export rmul=$(tput rmul)
export bold=$(tput bold)
export red=$(tput setaf 1)
export green=$(tput setaf 2)

# Abort if user is not a superuser on Linux
if [[ $EUID -ne 0 && $(uname) == 'Linux' ]]; then
   echo "${red}You must run mdl commands as a superuser.$norm" >&2
   exit 1
fi

# Returns the name of the script, trying to factor in whether you called the script
# directly or used the `mdl` script.
function script_name() {
   # shellcheck disable=SC2046
   local -r mdl=$(basename "$(readlink -- $(ps -o command -p $PPID))")
   echo "$mdl $(basename -s ".${mdl:+sh}" "$0")"
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

# Receives some content with fenced markers and replaces the content between the markers.
#
# Parameters:
# - `original_content`: The content to be modified.
# - `start_marker`: The marker that will start the replacement.
# - `end_marker`: The marker that will end the replacement.
# - `new_content`: The new content to put in the fenced area.
replace_fenced_content() {
   local original_content="$1"
   local start_marker="$2"
   local end_marker="$3"
   local new_content="$4"
   # Use awk to replace content between the comment tags
   echo "$original_content" | awk -v new_content="$new_content" "
   /$start_marker/ { print; print new_content; found=1; next }
   /$end_marker/ { print; found=0; next }
   found { next }
   { print }
   "
}

# Receives file path and decompresses it. Can detect bzip2, gzip and xz files. If none of
# those extensions match the filename, it throws an error. After successful decompression,
# the original file is deleted.
#
# Parameters:
# - `file_path`: Path to file to be decompressed. Required.
# - `out`: Path to output file. Defaults to file path without the compression extension.
function decompress() {
   local file_path=$1
   local out=$2
   local ext=${file_path##*.}
   local cmd
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
         rm -f "$file_path"
         echo "$out"
         return 0
      fi
      return 3
   fi
   # If we got here, the file is not compressed. Throw an error.
   return 2
}
