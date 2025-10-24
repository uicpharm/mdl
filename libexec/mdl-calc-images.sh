#!/bin/bash
#shellcheck disable=SC2059

. "${0%/*}/../lib/mdl-common.sh"

ver_chart_settings="%-7s %-45s %-45s\n"

# Load version matrix, including assessing if we need to download from internet
should_download_versions_file=false
[[ $* =~ -u || $* =~ --update ]] && should_download_versions_file=true
if [[ ! -f "$MDL_VERSIONS_FILE" ]]; then
   echo "Versions file not found. Expected at: $MDL_VERSIONS_FILE" >&2
   should_download_versions_file=true
elif (( MDL_VERSIONS_SOURCE_CHECK_FREQUENCY > 0 )); then
   mod=$(date -r "$MDL_VERSIONS_FILE" +%s 2>/dev/null || echo 0)
   now=$(date +%s)
   (( now - mod > MDL_VERSIONS_SOURCE_CHECK_FREQUENCY )) && should_download_versions_file=true
fi
if $should_download_versions_file; then
   echo "Downloading versions file from: $MDL_VERSIONS_SOURCE_URL"
   if new_versions_content=$(curl -fsL "$MDL_VERSIONS_SOURCE_URL"); then
      echo "$new_versions_content" > "$MDL_VERSIONS_FILE"
   else
      echo "Failed! Please check your internet connection or the URL." >&2
      exit 1
   fi
fi
if [[ ! -f "$MDL_VERSIONS_FILE" ]]; then
   echo 'Cannot get versions. Aborting.' >&2
   exit 1
fi

versions=()
versions_content=$(< "$MDL_VERSIONS_FILE")
include_line=false
while read -r line; do
   $include_line && versions+=("$line") || include_line=true
done <<< "$versions_content"
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

Options:
-h, --help      Show this help message and exit.
-u, --update    Update versions file now.
EOF
}

[[ $* =~ -h || $* =~ --help ]] && display_help && exit

# Positional parameter #1: Environment
if [[ $1 == -* || -z $1 ]]; then
   # Allow no env to be specified, in which case we just stop here.
   # This allows this script to at least do the version matrix download.
   exit
else
   mname=$("$scr_dir/mdl-select-env.sh" "$1" --no-all)
fi

branchver=${branchver:-$("$scr_dir/mdl-moodle-version.sh" "$mname")}

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

export MARIADB_IMAGE=$mariadb_ver
export MOODLE_IMAGE=$moodle_ver
