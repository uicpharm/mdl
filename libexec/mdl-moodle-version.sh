#!/bin/bash

. "${0%/*}/../lib/mdl-common.sh"

display_help() {
   cat <<EOF
Usage: $(script_name) <ENV>

Returns the Moodle version of a given Moodle environment, based on the Git branch it is
on. It returns only the numeric portion of the branch. So, for instance, if your Moodle
instance was on ${ul}MOODLE_402_STABLE$rmul, it would return ${ul}402$rmul.

Options:
-h, --help      Show this help message and exit.
EOF
}

[[ $* =~ -h || $* =~ --help ]] && display_help && exit

requires docker

mname=$("$scr_dir/mdl-select-env.sh" "$1" --no-all)
branchver="0"
src_vol_name=${src_vol_name:-$(docker volume ls -q --filter "label=com.docker.compose.project=$mname" | grep src)}
if [ -n "$src_vol_name" ]; then
   branchver=$(docker run --rm -t --name "${mname}_worker_git" -v "$src_vol_name":/src -w /src "$MDL_GIT_IMAGE" \
      -c safe.directory=/src \
      symbolic-ref --short HEAD | \
      cut -d'_' -f2 \
   )
fi
# If not numeric, set to zero.
[[ "$branchver" =~ ^[0-9]+$ ]] || branchver="0"
echo "$branchver"
