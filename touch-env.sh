#!/bin/bash

# This will `touch` the .env file to make sure it exists, and populate required values.
# There can be more values, but it populates the required values that scripts expect to
# see. It will be called by any script that does `source` on the .env file.
#
# You don't need to use/benefit from this. If you create a .env file before you begin, it
# will just be used. But this check makes sure things work as simply as possible.

. "${0%/*}/util/common.sh"
mname=$("$scr_dir"/select-env.sh "$1" --no-all)
env_path="$envs_dir/$mname/.env"

mkdir -p "$envs_dir/$mname"
touch "$env_path"
grep -qw ROOT_PASSWORD "$env_path" || echo ROOT_PASSWORD="$(openssl rand -hex 24)" >> "$env_path"
grep -qw DB_NAME "$env_path" || echo DB_NAME="moodle_$mname" >> "$env_path"
grep -qw DB_USERNAME "$env_path" || echo DB_USERNAME="moodleuser_$mname" >> "$env_path"
grep -qw DB_PASSWORD "$env_path" || echo DB_PASSWORD="$(openssl rand -hex 20)" >> "$env_path"
grep -qw MOODLE_HOST "$env_path" || echo MOODLE_HOST="$mname.local" >> "$env_path"
exit 0
