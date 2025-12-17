#!/bin/bash

display_help() {
   cat <<EOF
Usage: $0 [OPTIONS]

Installs the mdl CLI.

Options:
-h, --help         Show this help message and exit.
-d, --dev          Install in developer mode, just create a symlink.
EOF
}

[[ $* =~ -h || $* =~ --help ]] && display_help && exit
[[ $* =~ -d || $* =~ --dev ]] && dev=true || dev=false

# Params
branch=main
[[ $1 != -* && -n $1 ]] && branch=$1

# Requires curl
if ! command -v curl &>/dev/null; then
   echo "$(tput bold)$(tput setaf 1)This command requires $(tput smul)curl$(tput rmul) to work.$(tput sgr0)" >&2
   exit 1
fi

# If `mdl` is already installed, it must not be a symlink
mdl_path=$(command -v mdl)
if [[ -n $mdl_path && -L $mdl_path ]]; then
   echo 'The mdl CLI is already installed in developer mode. You do not have to reinstall' >&2
   echo 'it. If you want to reinstall it in normal mode, please uninstall it first.' >&2
   exit 1
fi

# Warn that we will ask for sudo password.
if [[ $EUID -ne 0 ]]; then
   echo "Part of the installation requires 'sudo'. You may be asked for a sudo password." >&2
else
   echo "You are running this installer as a superuser. That's fine, but that means only" >&2
   echo "the superuser will have access to the environments and configurations. If you" >&2
   echo "don't want this, please run this installer as a normal user. Only the parts of" >&2
   echo "installation that require escalated privileges will use 'sudo'." >&2
fi

# Install executable and its dependencies
base=/usr && [[ $(uname) == Darwin ]] && base=/usr/local
sudo install -d $base/bin
if $dev; then
   . "${0%/*}/../lib/mdl-common.sh"
   . "${0%/*}/../lib/mdl-ui.sh"
   mdl_title
   mdl_path=$(realpath "${0%/*}/../bin/mdl")
   mdl_dest=$base/bin/mdl
   sudo ln -s "$mdl_path" "$mdl_dest"
   echo "Installed mdl in developer mode as a symlink at: $mdl_dest"
else
   echo "Downloading installation files from $branch branch..."
   url=https://github.com/uicpharm/mdl/archive/refs/heads/$branch.tar.gz
   dir=$(mktemp -d)
   curl -fsL "$url" | tar xz --strip-components=1 -C "$dir"
   scr_dir="$dir/libexec"
   # shellcheck source=../lib/mdl-common.sh
   . "$dir/lib/mdl-common.sh" 2>/dev/null
   # shellcheck source=../lib/mdl-ui.sh
   . "$dir/lib/mdl-ui.sh" 2>/dev/null
   mdl_title
   sudo install -d $base/lib
   sudo install -d $base/libexec
   sudo install -b "$dir/bin/mdl" $base/bin
   for file in "$dir"/lib/mdl-*; do
      [[ -f $file ]] && sudo install -b "$file" $base/lib
   done
   for file in "$dir"/libexec/mdl-*; do
      [[ -f $file && ! -L $file  ]] && sudo install -b "$file" $base/libexec
   done
   for file in "$dir"/libexec/mdl-*; do
      [[ -L $file ]] && (
         cd $base/libexec || echo "Could not change to $base/libexec" >&2
         sudo ln -s -f "$(readlink "$file")" "$(basename "$file")"
      )
   done
fi
echo 🎉 The mdl CLI is installed!
echo

# Initialize the system
mdl init --no-title -c "${MDL_BASE_URL/main/$branch}/compose/default.yml"
