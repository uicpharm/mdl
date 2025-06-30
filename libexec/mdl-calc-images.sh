#!/bin/bash
#shellcheck disable=SC2059

. "${0%/*}/../lib/mdl-common.sh"

port_chart_settings="%-15s %-8s\n"
ver_chart_settings="%-9s %-11s %-11s\n"
versions=(
#   Branch  Moodle   MariaDB
   "39      3.9.2    10.5.27"
   "310     3.10.4   10.5.27"
   "311     3.11.12  10.5.37"
   "400     4.0.11   10.6.20"
   "401     4.1.15   10.11.11"
   "402     4.2.11   10.11.11"
   "403     4.3.8    10.11.11"
   "404     4.4.4    10.11.11"
   "405     4.5.4    10.11.11"
   "500     5.0.0    10.11.11"
)
first_ver=${versions[0]%% *}
last_ver=${versions[$((${#versions[@]} - 1))]%% *}

display_help() {
   cat <<EOF
Usage: $(script_name) <ENV>

Looks at the version of a Moodle environment, based on its Git branch, and returns the
MariaDB and Moodle images that should be used for that particular version. It returns
them as ${ul}MARIADB_IMAGE$rmul and ${ul}MOODLE_IMAGE$rmul environment variables.

$(
   printf "$ul$ver_chart_settings$rmul" "Branch" "Moodle" "MariaDB"
   for ver_string in "${versions[@]}"; do
      IFS=' ' read -ra var_array <<< "$ver_string"
      printf "$ver_chart_settings" "${var_array[0]}" "${var_array[1]}" "${var_array[2]}"
   done
)

It also returns the port that should be opened for the Moodle container as an
environment variable named ${ul}MOODLE_PORT$rmul.

$(
   printf "$ul$port_chart_settings$rmul" "Environment" "Port"
   num=8000
   for dir in "$MDL_ENVS_DIR"/*/; do
      (( num++ ))
      printf "$port_chart_settings" "$(basename "$dir")" "$num"
   done
)

Options:
-h, --help      Show this help message and exit.
EOF
}

[[ $* =~ -h || $* =~ --help ]] && display_help && exit

mname=$("$scr_dir"/mdl-select-env.sh "$1" --no-all)
branchver=$("$scr_dir/mdl-moodle-version.sh" "$mname")

# Handle defaults if an unexpected branch version is used
assumed_branchver=$branchver
(( branchver < first_ver )) && assumed_branchver=$first_ver
(( branchver > last_ver )) && assumed_branchver=$last_ver

for ver_string in "${versions[@]}"; do
   IFS=' ' read -ra var_array <<< "$ver_string"
   if [[ $assumed_branchver == "${var_array[0]}" ]]; then
      moodle_ver=${var_array[1]}
      mariadb_ver=${var_array[2]}
      break;
   fi
done

export MARIADB_IMAGE="docker.io/bitnami/mariadb:$mariadb_ver"
export MOODLE_IMAGE="docker.io/bitnami/moodle:$moodle_ver"

# Calculate Moodle port
num=8000
for dir in "$MDL_ENVS_DIR"/*/; do
   (( num++ ))
   if [[ $(basename "$dir") == "$mname" ]]; then
      export MOODLE_PORT=$num
      break
   fi
done
