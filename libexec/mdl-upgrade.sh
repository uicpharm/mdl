#!/bin/bash

. "${0%/*}/../lib/mdl-common.sh"

display_help() {
   cat <<EOF
Usage: $(script_name) <ENV> [TARGETBRANCH]

Upgrades the Moodle environment to the desired Moodle version. It can also be used to
pull down the latest hot fixes of the current version you're on if you just select the
same version.

Note this script technically just cleans up and fast forwards to the Git branch for the
version you specify, then reapplies any existing customizations. When the instance is
started up, Moodle will auto-upgrade the rest of its environment when it detects the new
source code.

Options:
-h, --help         Show this help message and exit.
EOF
}

[[ $* =~ -h || $* =~ --help ]] && display_help && exit

requires docker grep cut

mnames=$("$scr_dir/mdl-select-env.sh" "$1")
targetbranch="$2"

for mname in $mnames; do

   src_vol_name=${src_vol_name:-$(docker volume ls -q --filter "label=com.docker.compose.project=$mname" | grep src)}
   if [ -z "$src_vol_name" ]; then
      echo "Source code volume does not exist for $mname. Can't upgrade."
      exit 1
   fi

   # Stop the services if they're running
   "$scr_dir/mdl-stop.sh" "$mname"

   echo "Upgrading $mname..."
   function git_cmd() {
      docker run --rm --name "${mname}_worker_git" \
         -v "$src_vol_name":/src -w /src "$MDL_GIT_IMAGE" \
         -c safe.directory=/src "$@"
   }

   # Pull latest repo data
   git_cmd remote set-url origin https://github.com/moodle/moodle.git
   git_cmd fetch -np

   # Remove any untracked code
   git_cmd stash save -u
   git_cmd reset --hard
   git_cmd clean -dfe local
   curr_branch="$(git_cmd symbolic-ref --short HEAD)"
   echo "Your current branch: $curr_branch"
   git_cmd status -s -b

   # Get list of branches. If targetbranch isn't in list, prompt user to select one
   targetbranches="$(git_cmd branch -lr | grep -E "MOODLE_[3-9][0-9]+_STABLE" | cut -d"/" -f2)"
   echo "$targetbranches" | grep -qw "$targetbranch" || targetbranch=""
   if  [ -z "$targetbranch" ]; then
      PS3="Select the version to upgrade to: "
      select targetbranch in $targetbranches; do
         targetbranch="${targetbranch:-$REPLY}"
         echo "$targetbranches" | grep -qw "$targetbranch" && break
      done
   fi
   [ "$curr_branch" = "$targetbranch" ] && echo "You're on this branch now. Will fast forward to latest commit." || echo "Will switch to $targetbranch"

   # Pull/checkout new code
   if [ "$curr_branch" = "$targetbranch" ]; then
      git_cmd pull --ff-only --no-tags
   else
      git_cmd checkout -f --guess "$targetbranch"
   fi

   # Pop stash
   git_cmd stash pop

   echo 'Done!'

done
