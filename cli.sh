#!/bin/bash

. "${0%/*}/util/common.sh"

display_help() {
   cat <<EOF
Usage: $(script_name) <ENV> <COMMAND> [ARGS...]

Executes a Moodle CLI command in the environment you specify. You don't have to provide
the .php extension of the script you want to run.

Options:
-h, --help         Show this help message and exit.
-i, --interactive  Enable interactive mode while executing the command.

$bold${ul}Examples$norm

Enable maintenance mode:
   $bold$(script_name) \$mname maintenance --enable$norm

Disable maintenance mode:
   $bold$(script_name) \$mname maintenance --disable$norm

Reset password:
   $bold$(script_name) -i \$mname reset_password$norm

Purge cache:
   $bold$(script_name) \$mname purge_caches$norm
EOF
}

[[ $* =~ -h || $* =~ --help ]] && display_help && exit

paramI=''
for arg in "$@"; do
   if [[ $arg == -i || $arg == --interactive ]]; then
      paramI='-i'
      shift
      break
   fi
done
mnames=$("$scr_dir"/select-env.sh "$1")

for mname in $mnames; do

   cmd="$2"

   if [ "$cmd" = "" ]; then
      echo -n "Command to run: "
      read -r cmd
   fi

   # Get an existing moodle task on this node
   container="$(docker ps -f "label=com.docker.compose.project=$mname" --format '{{.Names}}' | grep moodle | head -1)"

   if [ -n "$container" ]; then
      docker exec $paramI -t "$container" php "/bitnami/moodle/admin/cli/$cmd.php" "${@:3}"
   else
      echo "Could not find a container running Moodle for $mname!"
      exit 1
   fi

done
