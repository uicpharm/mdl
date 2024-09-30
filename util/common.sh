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

function script_name() {
   # shellcheck disable=SC2046
   local -r mdl=$(basename "$(readlink -- $(ps -o command -p $PPID))")
   echo "$mdl $(basename -s ".${mdl:+sh}" "$0")"
}

function support_long_options() {
   # Ref: https://stackoverflow.com/a/28466267/519360
   if [ "$OPT" = "-" ]; then
      OPT="${OPTARG%%=*}"       # extract long option name
      OPTARG="${OPTARG#"$OPT"}" # extract long option argument (may be empty)
      OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
   fi
}
