#!/bin/bash

scr_dir="$(dirname "${BASH_SOURCE[0]}")"
mname=$("$scr_dir/select-env.sh" "$1" --no-all)
envs_dir="$scr_dir/environments"
env_dir="$envs_dir/$mname"

export mname

# We touch the .env file before we look at it.
"$scr_dir/touch-env.sh" "$mname"

# We update configs every time just so updating .env will naturally update the environment as well.
"$scr_dir/update-config.sh" "$mname"

# Clear the settings with blank.env to avoid any data leaks
# shellcheck disable=SC2046
export $(grep -v '^#' "$envs_dir/blank.env" | xargs)

# Load this env data
# shellcheck disable=SC2046
export $(grep -v '^#' "$env_dir/.env" | xargs)
