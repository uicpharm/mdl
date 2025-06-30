#!/bin/bash

. "${0%/*}/../lib/mdl-common.sh"

# Valid Options
valid_modules='src data db'
valid_compress='bzip2 gzip xz none'

# Defaults
default_modules='src data db'
default_compress_arg='bzip2'
default_label=$(date +%Y%m%d)
default_dest=$MDL_BACKUP_DIR

# Apply Defaults
modules=$default_modules
compress_arg=$default_compress_arg
label=$default_label
dest=$default_dest

# Declarations
source_host=
source_type=
compress_flag=
ssh_args=
sync=false
verbose=false
dry_run=false

# Help
display_help() {
   cat <<EOF
Usage:
  $(script_name) <ENV> container [HOST:][SOURCE] [DEST] [OPTIONS]
  $(script_name) <ENV> lamp [HOST] [DEST] [OPTIONS]

Make a backup of a Moodle environment. This can be a ${ul}container$norm environment or a
${ul}LAMP$norm environment, and it can be local or remote. However, the backup file can
only be saved to a local destination. If you want to send a backup to a remote
destination, use the ${ul}mdl cp$norm command to copy the backup after you've made it.

All options can be set in the environment's $ul.env$norm file. If you use the parameter
in your command call, that will override any value set in the .env file.

Options:
-h, --help      Show this help message and exit.
-l, --label     Label for the backup. Default is today's date. (i.e. $ul$default_label$norm)
-m, --modules   Which module to backup. ($(echo "${valid_modules}" | sed "s/ /, /g" | sed "s/\([^, ]*\)/${ul}\1$norm/g"))
-c, --compress  Which compression, default is $ul$default_compress_arg$norm. ($(echo "${valid_compress}" | sed "s/ /, /g" | sed "s/\([^, ]*\)/${ul}\1$norm/g"))
-s, --sync      Instead of saving a backup file, sync the local environment.
-e, --ssh-args  Additional SSH arguments to pass when using rsync/ssh.
-n, --dry-run   Show what would've happened without executing.
-v, --verbose   Provide more verbose output.

Source Options (for both LAMP and container sources):
--source-data-path      Path on source server to data path.
--source-src-path       Path on source server to src path.
--source-db-name        Name of the source database.
--source-db-username    Username for source database access.
--source-db-password    Password for source database access.

Source Options (only for LAMP sources):
--source-host           Hostname or IP of source.
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

# Positional parameter #3: Source
if [[ $source_type == container ]]; then
   if [[ $1 == -* || -z $1 ]]; then
      # If not provided, we assume it is this local environment
      source_full=$MDL_ENVS_DIR
   else
      source_full=$1
      shift
   fi
elif [[ $source_type != lamp ]]; then
   echo -e "${red}Source type must be ${ul}container$rmul or ${ul}lamp$rmul.$norm\n" >&2
   display_help; exit 1;
fi

# Positional parameter #4: Destination
if [[ $1 != -* && -n $1 ]]; then
   dest=$(realpath "$1") || exit 1
   shift
fi

# Collect optional arguments.
# shellcheck disable=SC2214
# spellchecker: disable-next-line
while getopts hsvnl:m:e:c:-: OPT; do
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
      e | ssh-args) ssh_args=$OPTARG ;;
      s | sync) sync=true ;;
      v | verbose) verbose=true ;;
      n | dry-run) dry_run=true ;;
      l | label) label=$OPTARG ;;
      source-host) param_source_host=$OPTARG ;;
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

# Disable some settings if sync is turned on
if $sync; then
   compress_arg=none
   dest=''
   label=''
fi

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
   if [[ ! "$valid_modules" =~ $m ]]; then
      echo -e "${red}Error: Invalid module type: $m.$norm\n" >&2
      exit 1
   fi
done

# Only valid compression option
if [[ ! "$valid_compress" =~ $compress_arg ]]; then
   echo -e "${red}Error: Invalid compression type: $compress_arg.$norm\n" >&2
   exit 1
fi

# Check necessary utilities
cmds=tar
[[ $compress_arg != none ]] && cmds="$cmds $compress_arg"
for cmd in $cmds; do
   if [[ -z $(which "$cmd" 2>/dev/null) ]]; then
      echo "${red}${bold}This command requires $ul$cmd$rmul to work.$norm" >&2
      exit 1
   fi
done

for mname in $mnames; do

   # Reset these values to empty string or the originally set parameter
   source_host=$param_source_host
   source_data_path=$param_source_data_path
   source_src_path=$param_source_src_path
   source_db_name=$param_source_db_name
   source_db_username=$param_source_db_username
   source_db_password=$param_source_db_password

   #
   # Calculations (Before .env load)
   #

   # For "container", find base and host parts from full source path (i.e. `server:/my/path` or `/my/path`)
   if [[ -n $source_full ]]; then
      source_host=$(echo "$source_full" | cut -d ':' -f1)
      source_base=$(echo "$source_full" | cut -d ':' -f2)
      # No colon, thus base/host are same? Assume it is a local path.
      [ "$source_host" = "$source_base" ] && source_host=''
      # If host is empty, calculate real path of base, proving it exists.
      if [[ -z $source_host ]]; then source_base=$(realpath "$source_base") || exit 1; fi
   fi
   # If base exists, set "data" and "src" paths if they didn't provide custom paths``
   [[ -n $source_base && -z $source_data_path ]] && source_data_path=$source_base/$mname/data
   [[ -n $source_base && -z $source_src_path ]] && source_src_path=$source_base/$mname/src

   # Get environment values and use them when no local value provided.
   # shellcheck source=../environments/sample.env
   . "$scr_dir/mdl-export-env.sh" "$mname"
   #  Preemptively use DB_NAME, DB_USERNAME, DB_PASSWORD for source database, if its a local backup (no host)
   if [[ -z $source_host ]]; then
      for env_var in DB_NAME DB_USERNAME DB_PASSWORD; do
         local_var=source_$(echo "$env_var" | tr '[:upper:]' '[:lower:]')
         [[ -z ${!local_var} ]] && declare "$local_var"="${!env_var}"
      done
   fi
   # Assign source values from environment
   for env_var in SOURCE_DATA_PATH SOURCE_SRC_PATH SOURCE_DB_NAME SOURCE_DB_USERNAME SOURCE_DB_PASSWORD; do
      local_var=$(echo "$env_var" | tr '[:upper:]' '[:lower:]')
      [[ -z ${!local_var} ]] && declare "$local_var"="${!env_var}"
   done
   # Assign source values that only apply to "lamp" source type
   [[ $source_type == lamp && -z $source_host ]] && declare source_host=$SOURCE_HOST

   #
   # Calculations
   #

   # Host server, and whether it's reachable
   source_host_server=$(echo "$source_host" | cut -d '@' -f2)
   if [[ -n $source_host_server ]]; then
      ping -c 1 "$source_host_server" &> /dev/null && source_host_reachable=true || source_host_reachable=false
   fi

   # If "container", the container must be active in order to dump the database for the "db" module.
   source_db_container=''
   if [[ $source_type == container ]] && [[ $modules =~ db ]]; then
      source_db_container_cmd="
         ${source_host:+"ssh $ssh_args $source_host sudo"} \
         docker ps -f 'label=com.docker.compose.project=$mname' --format '{{.Names}}' | grep mariadb | head -1
      "
      source_db_container=$(eval "$source_db_container_cmd")
      [[ -z $source_db_container ]] && echo "${red}The database container cannot be found. Aborting." >&2 && exit 1
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
   if $sync; then
      dest="$MDL_ENVS_DIR/$mname"
      [[ $modules =~ data ]] && data_target="$dest/data"
      [[ $modules =~ src ]] && src_target="$dest/src"
      [[ $modules =~ db ]] && db_target="$dest/backup.sql"
   else
      [[ $modules =~ data ]] && data_target="$dest/${mname}_${label}_data.tar$compress_ext"
      [[ $modules =~ src ]] && src_target="$dest/${mname}_${label}_src.tar$compress_ext"
      [[ $modules =~ db ]] && db_target="$dest/${mname}_${label}_db.sql$compress_ext"
   fi

   $sync && action_word='Syncing' || action_word='Backing up'
   echo -e "$ul$bold$action_word $mname environment$norm"
   if $verbose; then
      echo
      echo "$bold        Type:$norm $source_type"
      [[ -n $source_host ]] && echo "$bold        Host:$norm $source_host ($($source_host_reachable && echo "${green}reachable" || echo "${red}unreachable!")$norm)"
      [[ -n $source_base ]] && echo "$bold   Base Path:$norm $source_base"
      echo "$bold  'src' Path:$norm $source_src_path"
      echo "$bold 'data' Path:$norm $source_data_path"
      [[ -n $source_db_container ]] && echo "${bold}DB Container:$norm $source_db_container"
      [[ -n $source_db_name ]] && echo "$bold     DB Name:$norm $source_db_name"
      [[ -n $source_db_username ]] && echo "$bold DB Username:$norm $source_db_username"
      [[ -n $source_db_password ]] && echo "$bold DB Password:$norm $source_db_password_mask"
      echo
      [[ -n $dest ]] && echo "$bold Destination:$norm $dest"
      [[ -n $label ]] && echo "$bold       Label:$norm $label"
      echo "$bold     Modules:$norm $modules"
      echo "$bold    Compress:$norm $compress_arg"
      [[ -n $src_target ]] && echo "$bold  'src' Path: $norm$src_target"
      [[ -n $data_target ]] && echo "$bold 'data' Path: $norm$data_target"
      [[ -n $db_target ]] && echo "$bold     DB Path: $norm$db_target"
      echo
   fi

   if ! $source_host_reachable; then
      echo -e "${red}Source host $ul$source_host_server$rmul is not reachable.$norm\n" >&2
      exit 1
   fi

   # Stop the services if they're running (for sync only)
   if $sync; then
      if $dry_run; then
         echo -e "${red}We would stop $mname container, but this is a dry run.$norm\n"
      else
         "$scr_dir/mdl-stop.sh" "$mname"
      fi
   fi

   if $sync; then
      # Only for rsync, it wants the source dir to have an ending slash
      [[ $source_data_path != */ ]] && source_data_path="$source_data_path/"
      [[ $source_src_path != */ ]] && source_src_path="$source_src_path/"
      # shellcheck disable=SC2034
      data_cmd="
         rsync -aLq --delete --progress \
            -e 'ssh $ssh_args' \
            --rsync-path='sudo rsync' \
            --exclude='/trashdir/' \
            --exclude='/temp/' \
            --exclude='/sessions/' \
            --exclude='/localcache/' \
            --exclude='/cache/' \
            --exclude='/moodle-cron.log' \
            '$source_host:$source_data_path' '$data_target'
      "
      # shellcheck disable=SC2034
      src_cmd="
         rsync -aLq --delete --progress \
            -e 'ssh $ssh_args' \
            --rsync-path='sudo rsync' \
            '$source_host:$source_src_path' '$src_target'
      "
   else
      # shellcheck disable=SC2034
      data_cmd="
         ${source_host:+"ssh $ssh_args $source_host sudo"} \
         tar c $compress_flag \
            --no-xattrs \
            --exclude='./trashdir' \
            --exclude='./temp' \
            --exclude='./sessions' \
            --exclude='./localcache' \
            --exclude='./cache' \
            --exclude='./moodle-cron.log' \
            -C $source_data_path .
      "
      # shellcheck disable=SC2034
      src_cmd="
         ${source_host:+"ssh $ssh_args $source_host sudo"} \
         tar c $compress_flag --no-xattrs -C $source_src_path .
      "
   fi
   # TODO: When piping to compression program, a failed status of mysqldump will be lost.
   # shellcheck disable=SC2034
   db_cmd="
      ${source_host:+"ssh $ssh_args $source_host sudo"} \
      $([[ $source_type == container ]] && echo "docker exec '$source_db_container'") \
      mysqldump \
         --user='$source_db_username' \
         --password='$source_db_password' \
         --single-transaction \
         -C -Q -e --create-options \
         $source_db_name \
   "
   [[ $compress_arg != none ]] && db_cmd="$db_cmd | $compress_arg -cq9"
   for t in data src db; do
      if [[ $modules =~ $t ]]; then
         targ_var=${t}_target; targ=${!targ_var}
         cmd_var=${t}_cmd; cmd=${!cmd_var}
         echo "$mname $t: $targ"
         # In verbose mode, output the command, but mask the password and eliminate whitespace by echoing with word splitting.
         # shellcheck disable=2086
         $verbose && echo ${cmd//password=\'$source_db_password\'/password=\'$source_db_password_mask\'}
         if $dry_run; then
            echo -e "${red}Not executed. This is a dry run.$norm\n"
         else
            # Wrap command in separate bash shell
            cmd="/bin/bash -c \"$cmd\""
            # Add redirection, but only when target is not a directory. If it's a directory, we assume
            # we are trying to rsync. If not a directory (it is file or nonexistent), we assume it's a file.
            test -d "$targ" && targ_is_dir=true || targ_is_dir=false
            $targ_is_dir || cmd="$cmd > $targ"
            # Execute the command, and handle success/fail scenarios
            eval "$cmd" && success=true || success=false
            if $success; then
               # Handle database cleanup/permissions if syncing
               if $sync && [[ $t == db ]]; then
                  db_vol_name=$(docker volume ls -q --filter "label=com.docker.compose.project=$mname" | grep db)
                  [[ -n $db_vol_name ]] && echo "Clearing the database Docker volume... $(docker volume rm "$db_vol_name")"
                  docker_id="$(id -u docker 2>/dev/null)"
                  [[ -n $docker_id && -n $targ ]] && chown "$docker_id" "$targ"
               fi
            else
               # Delete the target file if it failed
               if ! $targ_is_dir; then
                  rm "$targ"
                  echo "Removed $(basename "$targ") because the $t backup failed." >&2
               fi
            fi
         fi
      fi &
   done

   # TODO: It'd be nice if we check if any of the steps failed, and exit non-zero if so.
   wait
   echo "$action_word of $mname environment is complete!"

done
