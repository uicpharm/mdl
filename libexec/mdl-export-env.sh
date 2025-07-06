#!/bin/bash

. "${0%/*}/util/common.sh"

display_help() {
   cat <<EOF
Usage: $(script_name) <ENV>

Handles all the tasks of loading values from $ul.env$rmul so they are accessible to other
scripts, including doing the initial touch of the .env file, updating configs, clearing
out existing values, and finally, loading the new values.

Options:
-h, --help      Show this help message and exit.
EOF
}

[[ $* =~ -h || $* =~ --help ]] && display_help && exit

mname=$("$scr_dir/select-env.sh" "$1" --no-all)
env_dir="$envs_dir/$mname"

export mname

# We touch the .env file before we look at it.
"$scr_dir/touch-env.sh" "$mname"

# We update configs every time just so updating .env will naturally update the environment as well.
"$scr_dir/update-config.sh" "$mname"

# Clear the settings with blank.env to avoid any data leaks. Only look at UPPERCASE keys.
# shellcheck disable=SC2046
export $(grep -E '^[A-Z_0-9]+=' "$envs_dir/blank.env" | xargs)

# Load this env data. Only look at UPPERCASE keys.
# shellcheck disable=SC2046
export $(grep -E '^[A-Z_0-9]+=' "$env_dir/.env" | xargs)
