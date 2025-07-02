#!/bin/bash

# Check that `mdl` is installed
if [[ -z $(which mdl) ]]; then
   echo "Could not find mdl. Are you sure it is installed?" >&2
   exit 1
fi

# Warn that we will ask for sudo password.
if [[ $EUID -ne 0 ]]; then
   echo "Part of uninstallation requires 'sudo'. You may be asked for a sudo password." >&2
fi

# Determine paths and load common functions``
install_root=$(realpath "$(dirname "$(realpath "$(which mdl)")")/..")
[[ -L $(which mdl) ]] && linked=true || linked=false
# shellcheck source=../lib/mdl-common.sh
[[ -f $install_root/lib/mdl-common.sh ]] && . "$install_root/lib/mdl-common.sh"
echo "$mdl_title"

# Run the Moodle system removal script
[[ -f $install_root/libexec/mdl-remove.sh ]] && "$install_root/libexec/mdl-remove.sh" --sys
echo

# Remove the mdl executable and its associated files
if $linked; then
   echo 'It appears you installed mdl in developer mode, which just installs a symlink to'
   echo 'the project in your path.'
   echo
   yorn "Do you want to remove the symlink?" y && sudo rm "$(which mdl)"
else
   yorn "Remove the mdl executable and its associated files?" y && \
   sudo rm -fv /usr/local/bin/mdl /usr/local/lib/mdl-*.sh /usr/local/libexec/mdl-*.sh
fi
echo 🎉 Done!
