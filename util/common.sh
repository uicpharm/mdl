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
