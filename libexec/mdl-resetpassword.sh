#!/bin/bash

. "${0%/*}/../lib/mdl-common.sh"

display_help() {
   cat <<EOF
Usage: $(script_name) <ENV> [OPTIONS...]

Interactively walks you through updating the user password. This is just a convenience
script for:

   ${bold}mdl cli -i \$mname reset_password$norm

You can pass it additional parameters that reset_password.php expects.

Options:
-h, --help         Show this help message and exit.
-u, --username     Specify username to change.
-p, --password     Specify new password.
$bold$ul
Examples
$norm
Reset password interactively:
   $bold$(script_name) \$mname$norm

Reset password with no interaction:
   $bold$(script_name) \$mname -u admin -p 'mygr8password!'$norm
EOF
}

[[ $* =~ -h || $* =~ --help ]] && display_help && exit

"$scr_dir/mdl-cli.sh" -i "$1" reset_password "${@:2}"
