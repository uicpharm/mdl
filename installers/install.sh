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

# Requires curl
if [[ -z $(which curl) ]]; then
   echo "$(tput bold)$(tput setaf 1)This command requires $(tput smul)curl$(tput rmul) to work.$(tput sgr0)" >&2
   exit 1
fi

# If `mdl` is already installed, it must not be a symlink
if [[ -n $(which mdl) && -L $(which mdl) ]]; then
   echo 'The mdl CLI is already installed in developer mode. You do not have to reinstall' >&2
   echo 'it. If you want to reinstall it in normal mode, please uninstall it first.' >&2
   exit 1
fi

# Warn that we will ask for sudo password.
if [[ $EUID -ne 0 ]]; then
   echo "Part of the installation requires 'sudo'. You may be asked for a sudo password." >&2
elif [[ -n $SUDO_USER ]]; then
   echo "Please do not run this installer with 'sudo'." >&2
   exit 1
else
   echo "You are running this installer as a superuser. That's fine, but that means only" >&2
   echo "the superuser will have access to the environments and configurations. If you" >&2
   echo "don't want this, please run this installer as a normal user. Only the parts of" >&2
   echo "installation that require escalated privileges will use 'sudo'." >&2
fi

# Install executable and its dependencies
sudo install -d /usr/local/bin
if $dev; then
   . "${0%/*}/../lib/mdl-common.sh"
   echo "$mdl_title"
   mdl_path=$(realpath "${0%/*}/../bin/mdl")
   mdl_dest=/usr/local/bin/mdl
   sudo ln -s "$mdl_path" "$mdl_dest"
   echo "Installed mdl in developer mode as a symlink at: $mdl_dest"
else
   url=https://github.com/uicpharm/mdl/archive/refs/heads/main.tar.gz
   url=https://github.com/uicpharm/mdl/archive/refs/heads/jcurt/public.tar.gz # TODO: temp
   dir=$(mktemp -d)
   curl -fsL $url | tar xz --strip-components=1 -C "$dir"
   # shellcheck source=../lib/mdl-common.sh
   . "$dir/lib/mdl-common.sh" 2>/dev/null
   echo "$mdl_title"
   sudo install -d /usr/local/lib
   sudo install -d /usr/local/libexec
   sudo install -b "$dir/bin/mdl" /usr/local/bin
   for file in "$dir"/lib/mdl-*; do
      [[ -f $file ]] && sudo install -b "$file" /usr/local/lib
   done
   for file in "$dir"/libexec/mdl-*; do
      [[ -f $file && ! -L $file  ]] && sudo install -b "$file" /usr/local/libexec
   done
   for file in "$dir"/libexec/mdl-*; do
      [[ -L $file ]] && (
         cd /usr/local/libexec || echo "Could not change to /usr/local/libexec" >&2
         sudo ln -s "$(readlink "$file")" "$(basename "$file")"
      )
   done
fi
echo 🎉 The mdl CLI is installed!
echo

# Initialize the system
mdl init --no-title
