#!/bin/bash

#
# These are functions that help with user interface work, like the title,
# prompts, etc.
#
# REQUIRES: mdl-common.sh
#

# Title for the script
# shellcheck disable=SC2154 # Uses vars expected from mdl-common.sh.
function mdl_title() {
   local -r ver=$("$scr_dir/../bin/mdl" -v)
   echo "$red"
   echo "     ░▒██████████▓░ ░▒█████▓░ ░▒█▒░           ░▓████▓░ ░▒█▓░      ░▒█▒░"
   echo "     ░▒█▒░░▒█▒░░▒█▒░░▒█▒░░▒█▒░░▒█▒░          ░▒█▒░░▒█▒░░▒█▓░      ░▒█▒░"
   echo "     ░▒█▒░░▒█▒░░▒█▒░░▒█▒░░▒█▒░░▒█▒░          ░▒█▒░     ░▒█▓░      ░▒█▒░"
   echo "     ░▒█▒░░▒█▒░░▒█▒░░▒█▒░░▒█▒░░▒█▒░          ░▒█▒░     ░▒█▓░      ░▒█▒░"
   echo "     ░▒█▒░░▒█▒░░▒█▒░░▒█▒░░▒█▒░░▒█▒░          ░▒█▒░     ░▒█▓░      ░▒█▒░"
   echo "     ░▒█▒░░▒█▒░░▒█▒░░▒█▒░░▒█▒░░▒█▒░          ░▒█▒░░▒█▒░░▒█▓░      ░▒█▒░"
   echo "     ░▒█▒░░▒█▒░░▒█▒░░▒█████▓░ ░▒███████▓▒░    ░▓████▓░ ░▒██████▓▒░░▒█▒░"
   echo "$norm$bold"
   echo "CLI for managing containerized Moodle environments! $(tput setaf 3)(${ver/mdl version /v})"
   echo "$norm"
}

# Asks a question and returns the response. If the user does not provide a response, it
# returns the default value. If no default is provided, it returns an empty string.
# $1: The question to ask
# $2: The default answer (optional)
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
# $1: The question to ask
# $2: The default answer (optional, default is 'y')
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
