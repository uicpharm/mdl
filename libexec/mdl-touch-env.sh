#!/bin/bash

. "${0%/*}/../lib/mdl-common.sh"

display_help() {
   cat <<EOF
Usage: $(script_name) <ENV>

Like the ${ul}touch$rmul command in Linux, this script ensures a .env file exists for an
environment. It also populates required settings in the file if they don't exist. Used
internally by other scripts to ensure an adequate .env file is present.

Options:
-h, --help      Show this help message and exit.
EOF
}

[[ $* =~ -h || $* =~ --help ]] && display_help && exit

requires touch grep

mname=$("$scr_dir"/mdl-select-env.sh "$1" --no-all)
env_path="$MDL_ENVS_DIR/$mname/.env"

mkdir -p "$MDL_ENVS_DIR/$mname"
touch "$env_path"
grep -qw ROOT_PASSWORD "$env_path" || echo ROOT_PASSWORD="$(openssl rand -hex 24)" >> "$env_path"
grep -qw DB_NAME "$env_path" || echo DB_NAME="moodle_$mname" >> "$env_path"
grep -qw DB_USERNAME "$env_path" || echo DB_USERNAME="moodleuser_$mname" >> "$env_path"
grep -qw DB_PASSWORD "$env_path" || echo DB_PASSWORD="$(openssl rand -hex 20)" >> "$env_path"
# Provide a default of "http://localhost:8000". This is a sane default, and the init
# script will look for this default to auto-build something with an available port.
grep -qw MOODLE_PORT "$env_path" || echo MOODLE_PORT=8000 >> "$env_path"
grep -qw MOODLE_HOST "$env_path" || echo MOODLE_HOST=localhost:8000 >> "$env_path"
grep -qw WWWROOT "$env_path" || echo WWWROOT=http://localhost:8000 >> "$env_path"
exit 0
