#!/bin/bash

scr_dir="$(realpath "${0%/*}")"
envs_dir="$scr_dir/environments"
mnames=$("$scr_dir/select-env.sh" "$1")

for mname in $mnames; do

   if [ ! -d "$envs_dir/$mname/src" ]; then
      echo "Source code directory does not exist for $mname. Can't upgrade."
      exit 1
   fi

   echo "Upgrading $mname..."
   cd "$envs_dir/$mname/src" || exit 1

   # Pull latest repo data
   git remote remove nevoband 2>/dev/null
   git remote set-url origin https://github.com/moodle/moodle.git
   git fetch -np

   # Remove any untracked code
   git reset --hard
   git clean -dfe local
   curr_branch="$(git symbolic-ref --short HEAD)"
   echo "Your current branch: $curr_branch"
   git status -s -b

   PS3="Select the version to upgrade to: "
   select targetbranch in $(git branch -lr | grep -E "MOODLE_[3-9][0-9]+_STABLE" | cut -d"/" -f2); do
      [ "$curr_branch" = "$targetbranch" ] && echo "You're on this branch now. Will fast forward to latest commit." || echo "Will switch to $targetbranch"
      break
   done

   # Pull/checkout new code
   if [ "$curr_branch" = "$targetbranch" ]; then
      git pull --ff-only --no-tags
   else
      git checkout -f --guess "$targetbranch"
   fi

   # Apply diff customizations, if an environment-specific 'customizations' directory exists
   [ -d '../customizations' ] && git apply -3 --whitespace=nowarn ../customizations/*.diff

   # Copy global customization files in-place
   rsync -r --exclude='scripts' --exclude='*.sql' "$scr_dir/customizations/" .

   cd "$scr_dir" || exit 1

   echo 'Done!'

done
