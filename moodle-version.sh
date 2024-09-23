#!/bin/bash

. "${0%/*}/util/common.sh"
mname=$("$scr_dir/select-env.sh" "$1" --no-all)
branchver="0"
if [ -d "$envs_dir/$mname/src" ]; then
   cd "$envs_dir/$mname/src" || exit 1
   branchver="$(git symbolic-ref --short HEAD | cut -d"_" -f2)"
fi
# If not numeric, set to zero.
[[ "$branchver" =~ ^[0-9]+$ ]] || branchver="0"
echo "$branchver"
