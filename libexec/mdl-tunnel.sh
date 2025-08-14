#!/bin/bash

. "${0%/*}/../lib/mdl-common.sh"

# Validation
valid_actions='start stop'

# Defaults
app_default=mariadb
port_default=3306

# Declarations
action=
host=
ssh_args=
app=$app_default
port=$port_default
container_tool=${MDL_CONTAINER_TOOL[*]}
verbose=false

# Help
display_help() {
   cat <<EOF
Usage: $(script_name) <ENV> <ACTION> [HOST]

Initiates a tunnel to the designated container, so that you can access a port that is not
typically exposed. For instance, this is useful for accessing the database service.

If you provide a host, it will initiate a tunnel to the host via SSH that resides in the
background until you stop the tunnel. If the remote host uses a different container tool
than your local system, you can specify it with the $bold--container-tool$norm option.

Valid actions: ${valid_actions// /, }

Options:
-h, --help            Show this help message and exit.
-a, --app             Which app service to connect to ($app_default)
-p, --port            Port to tunnel ($port_default)
-t, --container-tool  Which container tool to use (docker or podman).
-e, --ssh-args        Additional SSH arguments to pass when using ssh.
-v, --verbose         Provide more verbose output.
EOF
}

# Positional parameter #1: Environment
if [[ $1 == -* || -z $1 ]]; then
   [[ $1 == -h || $1 == --help ]] || echo -e "${red}You MUST provide the environment.$norm\n" >&2
   display_help; exit 1;
else
   mnames=$("$scr_dir/mdl-select-env.sh" "$1")
   shift
fi

# Positional parameter #2: Action
if [[ $1 == -* || -z $1 ]]; then
   [[ $1 == -h || $1 == --help ]] || echo -e "${red}You MUST provide an action.$norm\n" >&2
   display_help; exit 1;
else
   action=$1
   [[ ! $valid_actions =~ $action ]] && echo -e "${red}You MUST provide a valid action: ${valid_actions// /, }$norm\n" >&2 && exit 1
   shift
fi

# Positional parameter #3: Host
if [[ $1 != -* ]] && [[ -n $1 ]]; then
   host=$1
   shift
fi

requires "${MDL_CONTAINER_TOOL[0]}" ping grep head

# Collect optional arguments.
# shellcheck disable=SC2214
# spellchecker: disable-next-line
while getopts hva:p:e:-: OPT; do
   support_long_options
   case "$OPT" in
      h | help)
         display_help
         exit 0
         ;;
      e | ssh-args) ssh_args=$OPTARG ;;
      a | app) app=$OPTARG ;;
      p | port) port=$OPTARG ;;
      t | container-tool) container_tool=$OPTARG ;;
      v | verbose) verbose=true ;;
      \?) echo "${red}Invalid option: -$OPT$norm" >&2 ;;
      *) echo "${red}Some of these options are invalid:$norm $*" >&2; exit 2 ;;
   esac
done
shift $((OPTIND - 1))

for mname in $mnames; do

   #
   # Calculations
   #

   # Is host server reachable?
   if [[ -n $host ]]; then
      ping -c 1 "$host" &> /dev/null && host_reachable=true || host_reachable=false
   fi

   echo -e "${ul}${bold}Trying to $action $mname $app tunnel for port $port$norm"
   # Verbose settings list
   if $verbose; then
      echo
      [[ -n $host ]] && echo "${bold}Host:$norm $host (Reachable: $host_reachable)"
      echo "${bold}Environment:$norm $mname"
      echo "${bold}Application Service:$norm $app"
      echo "${bold}Port:$norm $port"
      echo
   fi

   # Abort if host is unreachable
   if ! $host_reachable; then
      echo -e "${red}Host $ul$host$rmul is not reachable.$norm\n" >&2
      exit 1
   fi

   #
   # The strategy of this script is to create a container using the `alpine/socat` image
   # to publish/forward the desired port of another container. If you provide a host to
   # connect to a remote server, it performs the commands on the remote server via SSH, to
   # create the `alpine/socat` container on the remote server, and then sets up an SSH
   # tunnel that runs in the background. Correspondingly, with the 'stop' action, it stops
   # the container and kills the background SSH tunnel process.
   #
   # Ref: https://hub.docker.com/r/alpine/socat
   # Ref: https://www.revsys.com/writings/quicktips/ssh-tunnel.html
   #
   ssh_cmd=${host:+"ssh $ssh_args $host sudo"}
   if [[ $action == start ]]; then
      container=$(eval "$ssh_cmd $container_tool ps -f 'label=com.docker.compose.project=$mname' --format '{{.Names}}' | grep $app | head -1")
      [[ -z $container ]] && echo "${red}No $mname $app container found.$norm" >&2 && exit 1
      name="$container-tunnel-$port"
      cmd="$container_tool run --rm -d --name=$name --network=${mname}_backend -p $port:$port $MDL_SOCAT_IMAGE TCP-LISTEN:$port,fork TCP:$container:$port"
      ssh_post_cmd=${host:+"ssh -f -N -L $port:localhost:$port $ssh_args $host"}
   elif [[ $action == stop ]]; then
      container=$(eval "$ssh_cmd $container_tool ps --format '{{.Names}}' | grep $mname | grep $app | grep tunnel | grep $port | head -1")
      [[ -z $container ]] && echo "${red}Could not find $mname $app tunnel to stop.$norm" >&2 && exit 1
      cmd="$container_tool stop $container"
      ssh_post_cmd=${host:+"ps ax|grep 'ssh -f -N -L'|grep $port:localhost:$port|grep $host|awk '{print \$1}'|xargs kill"}
   fi
   if [[ -n $cmd ]] && out=$(eval "$ssh_cmd $cmd"); then
      echo "Successful $action: $out"
      eval "$ssh_post_cmd"
   fi

done
