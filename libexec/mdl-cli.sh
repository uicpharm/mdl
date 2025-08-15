#!/bin/bash

. "${0%/*}/../lib/mdl-common.sh"

display_help() {
   cat <<EOF
Usage: $(script_name) <ENV> <COMMAND> [ARGS...]

Executes a Moodle CLI command in the environment you specify. You don't have to provide
the .php extension of the script you want to run.

If you don't provide the command you want to run, it will list all of the available
commands provided by the environment.

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

Get list of available commands:
   $bold$(script_name) \$mname$norm
EOF
}

# Since they may use "-h" to get help in the CLI call, we only output our help screen if
# they ONLY passed "-h" or "--help", and no other parameters.
[[ $* == -h || $* == --help ]] && display_help && exit

requires docker

paramI=''
for arg in "$@"; do
   if [[ $arg == -i || $arg == --interactive ]]; then
      paramI='-i'
      shift
      break
   fi
done
mnames=$("$scr_dir"/mdl-select-env.sh "$1")

for mname in $mnames; do

   # Get the Moodle container for this environment
   container="$(docker ps -f "label=com.docker.compose.project=$mname" --format '{{.Names}}' | grep moodle | head -1)"
   [[ -z $container ]] && echo "${red}Could not find a container running Moodle for $ul$mname$rmul!$norm" >&2 && exit 1

   cmd="$2"
   # If they did not provide a cmd, list the available commands
   if [[ -z $cmd ]]; then
      echo "${bold}${ul}Available Commands$norm"
      docker exec -t "$container" find /bitnami/moodle/admin/cli -maxdepth 1 -type f -exec basename {} .php \; | sort | sed 's/^/  - /'
      exit
   fi

   # Run the command, passing any additional arguments they passed on to this script
   docker exec $paramI -t "$container" php "/bitnami/moodle/admin/cli/$cmd.php" "${@:3}"

done
