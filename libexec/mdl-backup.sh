#!/bin/bash

. "${0%/*}/../lib/mdl-common.sh"

# Valid Options
valid_modules='src data db fastdb'
valid_compress='bzip2 gzip xz none'

# Defaults
default_modules='src data db'
default_compress_arg='bzip2'
default_label=$(date +%Y%m%d)

# Apply Defaults
modules=$default_modules
compress_arg=$default_compress_arg
label=$default_label

# Declarations
source_host=
source_type=
compress_flag=
ssh_args=
container_tool=${MDL_CONTAINER_TOOL[*]}
verbose=false
dry_run=false

# Help
display_help() {
   cat <<EOF
Usage:
  $(script_name) <ENV> <container/lamp> [SOURCE] [OPTIONS]

Make a backup of a Moodle environment. This can be a ${ul}container$norm environment or a
${ul}LAMP$norm environment, and it can be local or remote. However, the backup files will
be saved in the standard Moodle backups directory. If you want to send a backup to another
destination, use the ${ul}mdl cp$norm command to copy the backup after you've made it.

All options can be set in the environment's $ul.env$norm file. If you use the parameter
in your command call, that will override any value set in the .env file.

Options:
-h, --help            Show this help message and exit.
-l, --label           Label for the backup. Default is today's date. (i.e. $ul$default_label$norm)
-m, --modules         Which module to backup. ($(echo "${valid_modules}" | sed "s/ /, /g" | sed "s/\([^, ]*\)/${ul}\1$norm/g"))
-c, --compress        Which compression, default is $ul$default_compress_arg$norm. ($(echo "${valid_compress}" | sed "s/ /, /g" | sed "s/\([^, ]*\)/${ul}\1$norm/g"))
-f, --fastdb          Perform an unsafe fast database backup instead of a SQL dump.
-e, --ssh-args        Additional SSH arguments to pass when using ssh.
-t, --container-tool  Which container tool to use (docker or podman).
-n, --dry-run         Show what would've happened without executing.
-v, --verbose         Provide more verbose output.

Source Options (for both LAMP and container sources):
--source-host           Hostname or IP of source.
--source-sudo           Use sudo command when connecting to source.
--source-db-name        Name of the source database.
--source-db-username    Username for source database access.
--source-db-password    Password for source database access.

Source Options (only for LAMP sources):
--source-data-path      Path on source server to data path.
--source-src-path       Path on source server to src path.
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

# Positional parameter #2: Source Type (container/lamp)
if [[ $1 == -* || -z $1 ]]; then
   echo -e "${red}You MUST provide the source type (${ul}container$rmul or ${ul}lamp$rmul).$norm\n" >&2
   display_help; exit 1;
else
   source_type="$(echo "$1" | tr '[:upper:]' '[:lower:]' | tr -d 's')"
   shift
fi
[[ $source_type == container ]] && is_container=true || is_container=false

if [[ $source_type != lamp && $source_type != container ]]; then
   echo -e "${red}Source type must be ${ul}container$rmul or ${ul}lamp$rmul.$norm\n" >&2
   display_help; exit 1;
fi

# Positional parameter #3: Source
if [[ $1 != -* && -n $1 ]]; then
   source_full=$1
   shift
fi

# Collect optional arguments.
# shellcheck disable=SC2214
# spellchecker: disable-next-line
while getopts hfsvnl:m:e:c:-: OPT; do
   support_long_options
   case "$OPT" in
      h | help)
         display_help
         exit 0
         ;;
      m | modules)
         # They can pass multiple values as "one two" or "one,two". We sub "," to " ". Convert to lowercase.
         modules=$(echo "${OPTARG//,/ }" | tr '[:upper:]' '[:lower:]') ;;
      c | compress)
         # Convert to lowercase.
         compress_arg=$(echo "$OPTARG" | tr '[:upper:]' '[:lower:]')
         ;;
      f | fastdb)
         # Remove "db" and add "fastdb" to modules list
         new_modules='fastdb'
         for word in $modules; do
            [[ $word == db || $word == fastdb ]] || new_modules="$new_modules $word"
         done
         modules=$new_modules
         ;;
      e | ssh-args) ssh_args=$OPTARG ;;
      v | verbose) verbose=true ;;
      n | dry-run) dry_run=true ;;
      l | label) label=$OPTARG ;;
      t | container-tool) container_tool=$OPTARG ;;
      source-host) param_source_host=$OPTARG ;;
      source-sudo) param_source_sudo=$OPTARG ;;
      source-data-path) param_source_data_path=$OPTARG ;;
      source-src-path) param_source_src_path=$OPTARG ;;
      source-db-name) param_source_db_name=$OPTARG ;;
      source-db-username) param_source_db_username=$OPTARG ;;
      source-db-password) param_source_db_password=$OPTARG ;;
      \?) echo "${red}Invalid option: -$OPT$norm" >&2 ;;
      *) echo "${red}Some of these options are invalid:$norm $*" >&2; exit 2 ;;
   esac
done
shift $((OPTIND - 1))

#
# Calculations
#

# Figure out the compression flag to send to tar
[[ $compress_arg != none ]] && compress_flag="--$compress_arg"

#
# Pre-environment Validation
#

# Backing up multiple environments for "LAMP" sources is not supported.
if [[ $source_type == lamp && $(echo "$mnames" | wc -w) -gt 1 ]]; then
   echo -e "${red}Error: When backing up LAMP sources, you must specify one environment at a time.$norm\n" >&2
   exit 1
fi

# Only valid modules
for m in $modules; do
   if [[ " $valid_modules " != *" $m "* ]]; then
      echo -e "${red}Error: Invalid module type: $m.$norm\n" >&2
      exit 1
   fi
done

# Only valid compression option
if [[ ! "$valid_compress" =~ $compress_arg ]]; then
   echo -e "${red}Error: Invalid compression type: $compress_arg.$norm\n" >&2
   exit 1
fi

# Fast DB backup is only for container sources
if [[ $modules =~ fastdb ]]; then
   if $is_container; then
      echo -e "${yellow}Warning: Fast database backups are unsafe for production use.$norm\n" >&2
   else
      echo -e "${red}Error: Fast database backups are only supported for container sources.$norm\n" >&2
      exit 1
   fi
fi


# Check necessary utilities
cmds=(tar "${MDL_CONTAINER_TOOL[0]}")
[[ $compress_arg != none ]] && cmds+=("$compress_arg")
requires "${cmds[@]}"

for mname in $mnames; do

   # Reset these values to empty string or the originally set parameter
   source_host=$param_source_host
   source_sudo=$param_source_sudo
   source_data_path=$param_source_data_path
   source_src_path=$param_source_src_path
   source_db_name=$param_source_db_name
   source_db_username=$param_source_db_username
   source_db_password=$param_source_db_password

   #
   # Calculations (Before .env load)
   #

   # Find base and host parts from full source path (i.e. `server:/my/path` or `user@server`)
   if [[ -n $source_full ]]; then
      source_host=$(echo "$source_full" | cut -d ':' -f1)
      source_host_server=$(echo "$source_host" | cut -d '@' -f2)
      # We only calculate source_base when not working on containers
      $is_container || source_base=$(echo "$source_full" | cut -d ':' -f2)
      # No colon, thus base/host are same? Assume it is a host.
      [ "$source_host" = "$source_base" ] && source_base=''
   fi
   # If host is empty, calculate real path of base, proving it exists.
   if [[ -z $source_host && -n $source_base ]]; then
      source_base=$(realpath "$source_base") || exit 1
   fi
   # If base exists, set "data" and "src" paths if they didn't provide custom paths``
   [[ -n $source_base && -z $source_data_path ]] && source_data_path=$source_base/data
   [[ -n $source_base && -z $source_src_path ]] && source_src_path=$source_base/src

   #
   # Calculations
   #

   # Get environment values and use them when no local value provided.
   export_env "$mname"
   #  Preemptively use DB_NAME, DB_USERNAME, DB_PASSWORD for source database, if its a local backup (no host)
   if [[ -z $source_host ]]; then
      for env_var in DB_NAME DB_USERNAME DB_PASSWORD; do
         local_var=source_$(echo "$env_var" | tr '[:upper:]' '[:lower:]')
         [[ -z ${!local_var} ]] && declare "$local_var"="${!env_var}"
      done
   fi
   # Assign source values from environment
   $is_container && var_ignore_list='source_data_path source_src_path'
   for env_var in SOURCE_DATA_PATH SOURCE_SRC_PATH SOURCE_SUDO SOURCE_DB_NAME SOURCE_DB_USERNAME SOURCE_DB_PASSWORD; do
      local_var=$(echo "$env_var" | tr '[:upper:]' '[:lower:]')
      [[ $var_ignore_list =~ $local_var ]] && continue
      [[ -z ${!local_var} ]] && declare "$local_var"="${!env_var}"
   done

   # Host server, and whether it's reachable
   if [[ -n $source_host_server ]]; then
      ping -c 1 "$source_host_server" &> /dev/null && source_host_reachable=true || source_host_reachable=false
   fi

   # If "container", the container must be active in order to dump the database for the "db" module.
   source_db_container=''
   if $is_container; then
      if [[ " $modules " == *" db "* ]]; then
         source_db_container_cmd="
            ${source_host:+"ssh $ssh_args $source_host $source_sudo \"sh -l -c \\\""}
            $container_tool ps -f 'label=com.docker.compose.project=$mname' --format '{{.Names}}' | grep mariadb | head -1
            ${source_host:+"\\\"\""}
         "
         source_db_container=$(eval "$source_db_container_cmd")
         [[ -z $source_db_container ]] && echo "${red}The database container cannot be found. Start the environment to perform a backup." >&2 && exit 1
      fi
      if [[ $modules =~ data || $modules =~ src || $modules =~ fastdb ]]; then
         vols_cmd="
            ${source_host:+"ssh $ssh_args $source_host $source_sudo \"sh -l -c \\\""}
            $container_tool volume ls -q --filter 'label=com.docker.compose.project=$mname'
            ${source_host:+"\\\"\""}
         "
         vols=$(eval "$vols_cmd")
         [[ $modules =~ data ]] && source_data_volume=$(grep data <<< "$vols")
         [[ $modules =~ src ]] && source_src_volume=$(grep src <<< "$vols")
         [[ $modules =~ fastdb ]] && source_db_volume=$(grep db <<< "$vols")
      fi
   fi

   # Password mask
   source_db_password_mask=${source_db_password//?/*}

   # Compression extension
   compress_ext=''
   case "$compress_arg" in
      bzip2) compress_ext='.bz2' ;;
      gzip) compress_ext='.gz' ;;
      xz) compress_ext='.xz' ;;
   esac

   # Targets
   [[ $modules =~ data ]] && data_target="$MDL_BACKUP_DIR/${mname}_${label}_data.tar$compress_ext"
   [[ $modules =~ src ]] && src_target="$MDL_BACKUP_DIR/${mname}_${label}_src.tar$compress_ext"
   [[ $modules =~ fastdb ]] && fastdb_target="$MDL_BACKUP_DIR/${mname}_${label}_dbfiles.tar$compress_ext"
   [[ " $modules " == *" db "* ]] && db_target="$MDL_BACKUP_DIR/${mname}_${label}_db.sql$compress_ext"

   action_word='Backing up'
   echo -e "$ul$bold$action_word $mname environment$norm"
   if $verbose; then
      echo
                                       echo "$bold          Type:$norm $source_type"
      [[ -n $source_host ]] &&         echo "$bold          Host:$norm $source_host ($($source_host_reachable && echo "${green}reachable" || echo "${red}unreachable!")$norm)"
      [[ -n $source_src_path ]] &&     echo "$bold    'src' Path:$norm $source_src_path"
      [[ -n $source_data_path ]] &&    echo "$bold   'data' Path:$norm $source_data_path"
      [[ -n $source_src_volume ]] &&   echo "$bold  'src' Volume:$norm $source_src_volume"
      [[ -n $source_data_volume ]] &&  echo "$bold 'data' Volume:$norm $source_data_volume"
      [[ -n $source_db_volume ]] &&    echo "$bold   'db' Volume:$norm $source_db_volume"
      [[ -n $source_db_container ]] && echo "$bold  DB Container:$norm $source_db_container"
      [[ -n $source_db_name ]] &&      echo "$bold       DB Name:$norm $source_db_name"
      [[ -n $source_db_username ]] &&  echo "$bold   DB Username:$norm $source_db_username"
      [[ -n $source_db_password ]] &&  echo "$bold   DB Password:$norm $source_db_password_mask"
      echo
      [[ -n $label ]] &&               echo "$bold         Label:$norm $label"
                                       echo "$bold       Modules:$norm $modules"
                                       echo "$bold      Compress:$norm $compress_arg"
      [[ -n $src_target ]] &&          echo "$bold    'src' Path:$norm $src_target"
      [[ -n $data_target ]] &&         echo "$bold   'data' Path:$norm $data_target"
      [[ -n $db_target ]] &&           echo "$bold       DB Path:$norm $db_target"
      [[ -n $fastdb_target ]] &&       echo "$bold  Fast DB Path:$norm $fastdb_target"
      echo
   fi

   if ! $source_host_reachable; then
      echo -e "${red}Source host $ul$source_host_server$rmul is not reachable.$norm\n" >&2
      exit 1
   fi

   # MODULE: data
   # shellcheck disable=SC2034
   data_cmd=${source_host:+"ssh $ssh_args $source_host $source_sudo \"sh -l -c \\\""}
   $is_container && data_cmd="$data_cmd $container_tool run --rm --name '${mname}_worker_bk_data' -v '$source_data_volume':/data $MDL_SHELL_IMAGE"
   data_cmd="$data_cmd \
      tar c $compress_flag \
         --exclude='./trashdir' \
         --exclude='./temp' \
         --exclude='./sessions' \
         --exclude='./localcache' \
         --exclude='./cache' \
         --exclude='./moodle-cron.log' \
         -C $($is_container && echo /data || echo "$source_data_path") . \
   "
   data_cmd=$data_cmd${source_host:+"\\\"\""}

   # MODULE: src
   # shellcheck disable=SC2034
   src_cmd=${source_host:+"ssh $ssh_args $source_host $source_sudo \"sh -l -c \\\""}
   $is_container && src_cmd="$src_cmd $container_tool run --rm --name '${mname}_worker_bk_src' -v '$source_src_volume':/src $MDL_SHELL_IMAGE"
   src_cmd="$src_cmd \
      tar c $compress_flag \
         -C $($is_container && echo /src || echo "$source_src_path") . \
   "
   src_cmd=$src_cmd${source_host:+"\\\"\""}

   # MODULE: fastdb
   # shellcheck disable=SC2034
   fastdb_cmd=${source_host:+"ssh $ssh_args $source_host $source_sudo \"sh -l -c \\\""}
   $is_container && fastdb_cmd="$fastdb_cmd $container_tool run --rm --name '${mname}_worker_bk_fastdb' -v '$source_db_volume':/db $MDL_SHELL_IMAGE"
   $is_container && fastdb_cmd="$fastdb_cmd tar c $compress_flag -C /db ."
   fastdb_cmd=$fastdb_cmd${source_host:+"\\\"\""}

   # MODULE: db
   # TODO: When piping to compression program, a failed status of mysqldump will be lost.
   # shellcheck disable=SC2034
   db_cmd=${source_host:+"ssh $ssh_args $source_host $source_sudo \"sh -l -c \\\""}
   $is_container && db_cmd="$db_cmd $container_tool exec '$source_db_container'"
   db_cmd="$db_cmd \
      mysqldump \
         --user='$source_db_username' \
         --password='$source_db_password' \
         --single-transaction \
         -C -Q -e --create-options \
         $source_db_name \
   "
   db_cmd=$db_cmd${source_host:+"\\\"\""}
   [[ $compress_arg != none ]] && db_cmd="$db_cmd | $compress_arg -cq9"

   # Actually EXECUTE the commands
   pids=()
   for t in $valid_modules; do
      if [[ " $modules " == *" $t "* ]]; then
         targ_var=${t}_target; targ=${!targ_var}
         cmd_var=${t}_cmd; cmd=${!cmd_var}
         echo "$mname $t: $targ"
         # In verbose mode, output the command, but mask the password and eliminate whitespace by echoing with word splitting.
         # shellcheck disable=2086
         $verbose && echo ${cmd//password=\'$source_db_password\'/password=\'$source_db_password_mask\'}
         if $dry_run; then
            echo -e "${red}Not executed. This is a dry run.$norm\n"
         else
            cmd="$cmd > '$targ'"
            # Execute the command, and handle success/fail scenarios
            eval "$cmd" && success=true || success=false
            if ! $success; then
               # Delete the target file if it failed
               rm "$targ"
               echo "Removed $(basename "$targ") because the $t backup failed." >&2
            fi
         fi
      fi &
      pids+=($!)
   done

   # TODO: It'd be nice if we check if any of the steps failed, and exit non-zero if so.
   wait "${pids[@]}"
   echo "$action_word of $mname environment is complete!"

   # Unset environment variables
   unset_env "$mname"

done
