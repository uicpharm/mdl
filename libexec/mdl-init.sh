#!/bin/bash

. "${0%/*}/../lib/mdl-common.sh"

# Defaults
compose_file_url=$MDL_BASE_URL/compose/compose.yml
display_title=true
force=false
install_moodle=true

# Help
display_help() {
   cat <<EOF
Usage: $(script_name) <ENV> [OPTIONS]

Initializes a Moodle environment and, if the system isn't initialized,
sets up the directories and configuration files for the system.

Options:
-h, --help             Show this help message and exit.
-c, --compose-file-url URL to download compose file for this system.
-f, --force            Force initialization even if already initialized.
    --no-title         Do not display the title banner.
    --skip-install     Do not install a fresh environment when setting
                       up the Moodle environment. Just allocate it.
EOF
}

# Positional parameter #1: Environment
[[ $1 != -* && -n $1 ]] && mname="$1" && shift

# Collect optional arguments.
# shellcheck disable=SC2214
# spellchecker: disable-next-line
while getopts hc:f-: OPT; do
   support_long_options
   case "$OPT" in
      h | help) display_help; exit ;;
      c | compose-file-url) compose_file_url=$OPTARG ;;
      f | force) force=true ;;
      no-title) display_title=false ;;
      skip-install) install_moodle=false ;;
      \?) echo "${red}Invalid option: -$OPT$norm" >&2 ;;
      *) echo "${red}Some of these options are invalid:$norm $*" >&2; exit 2 ;;
   esac
done
shift $((OPTIND - 1))

requires "${MDL_CONTAINER_TOOL[0]}" curl uuidgen

# Positional parameter #1: Environment
[[ $1 != -* && -n $1 ]] && mname="$1"

$display_title && mdl_title

should_init_system=false
! "$scr_dir/mdl-info.sh" -q && should_init_system=true
[[ -z $mname ]] && $force && should_init_system=true
if $should_init_system; then
   echo "Let's get started! Please answer these configuration questions. You can change"
   echo "them later by editing the configuration file saved at:"
   echo "$ul$MDL_CONFIG_FILE$rmul"
   # TODO: Calculate whether docker/podman exists.
   # TODO: Offer to install docker/podman if neither exists.
   MDL_ENVS_DIR=$(ask "Where do you want to store environments?" "$MDL_ENVS_DIR")
   MDL_BACKUP_DIR=$(ask "Where do you want to store backups?" "$MDL_BACKUP_DIR")
   MDL_COMPOSE_DIR=$(ask "Where do you want to store Docker Compose files?" "$MDL_COMPOSE_DIR")
   MDL_VERSIONS_FILE=$(ask "Where do you want to store the versions file?" "$MDL_VERSIONS_FILE")
   MDL_VERSIONS_SOURCE_URL=$(ask "Where do you want to download the versions file from?" "$MDL_VERSIONS_SOURCE_URL")
   MDL_VERSIONS_SOURCE_CHECK_FREQUENCY=$(ask "How often do you want to check for updates to the versions file (in seconds)?" "$MDL_VERSIONS_SOURCE_CHECK_FREQUENCY")
   install -d "$MDL_ROOT"
   echo '# This file is used to configure the mdl script.' > "$MDL_CONFIG_FILE"
   echo >> "$MDL_CONFIG_FILE"
   for x in MDL_ENVS_DIR MDL_BACKUP_DIR MDL_COMPOSE_DIR MDL_VERSIONS_FILE MDL_VERSIONS_SOURCE_URL MDL_VERSIONS_SOURCE_CHECK_FREQUENCY; do
      echo "$x='${!x}'" >> "$MDL_CONFIG_FILE"
   done
   echo "Configuration saved to: $ul$MDL_CONFIG_FILE$rmul"
   install -d "$MDL_ENVS_DIR"
   install -d "$MDL_BACKUP_DIR"
   install -d "$MDL_COMPOSE_DIR"
   if [[ -L $(which mdl) ]]; then
      # If in dev mode, link to the project compose file.
      compose_file=$(realpath "$scr_dir/../compose/compose.yml")
      echo 'Since mdl is in developer mode, installing symlink to compose file at:'
      echo "$ul$compose_file$rmul"
      ln -s -F "$compose_file" "$MDL_COMPOSE_DIR/compose.yml"
   elif [[ -n $compose_file_url ]]; then
      # Download the provided compose file URL.
      echo 'Downloading compose file from:'
      echo "$ul$compose_file_url$rmul"
      if ! curl -fsL "$compose_file_url" -o "$MDL_COMPOSE_DIR/compose.yml"; then
         echo "Failed to download compose file. Please check your internet connection or the URL." >&2
         exit 1
      fi
   elif [[ -e $MDL_COMPOSE_DIR/compose.yml ]]; then
      # A blank compose file URL was provided, but it's ok, because a file is present.
      echo 'Skipping compose file download. That is ok because one is already installed.'
   else
      # A blank compose file URL was provided, and they don't have one. This will break
      # things, so we are forced to abort.
      echo 'Skipped compose file download because no URL was provided.' >&2
      echo 'This step is critical, so we need to abort.' >&2
      exit 1
   fi
   "$scr_dir/mdl-calc-images.sh"
elif [[ -z $mname ]]; then
   echo 'Your system is already initialized!'
fi

if [[ -n $mname ]]; then
   if [[ ! -d "$MDL_ENVS_DIR/$mname" ]] || $force; then
      echo "Creating environment: $ul$mname$rmul"
      mkdir -p "$MDL_ENVS_DIR/$mname"
      export_env "$mname"
      echo "Environment created at: $ul$MDL_ENVS_DIR/$mname$rmul"
      echo
      echo "${ul}Database Configuration$rmul"
      DB_NAME=$(ask "Database name" "$DB_NAME")
      ROOT_PASSWORD=$(ask "Root password" "$ROOT_PASSWORD")
      DB_USERNAME=$(ask "Database username" "$DB_USERNAME")
      DB_PASSWORD=$(ask "Database password" "$DB_PASSWORD")
      echo
      echo "${ul}Moodle Configuration$rmul"
      MOODLE_HOST=$(ask "Host name" "$MOODLE_HOST")
      WWWROOT=$(ask "Site address" "$WWWROOT")
      echo
      echo "${ul}Remote Source Server Configuration$rmul"
      echo
      echo 'If you will use a remote server to download a Moodle environment on that server,'
      echo 'please provide the following information.'
      echo
      default_answer=n
      if [[ -n $SOURCE_HOST || -n $SOURCE_DATA_PATH || -n $SOURCE_SRC_PATH || -n $SOURCE_DB_NAME || -n $SOURCE_DB_USERNAME || -n $SOURCE_DB_PASSWORD ]]; then
         default_answer=y
      fi
      if yorn "Do you want to use a remote source server?" "$default_answer"; then
         SOURCE_HOST=$(ask "Remote server host" "$SOURCE_HOST")
         SOURCE_DATA_PATH=$(ask "Remote server data path" "$SOURCE_DATA_PATH")
         SOURCE_SRC_PATH=$(ask "Remote server source path" "$SOURCE_SRC_PATH")
         SOURCE_DB_NAME=$(ask "Remote server database name" "$SOURCE_DB_NAME")
         SOURCE_DB_USERNAME=$(ask "Remote server database username" "$SOURCE_DB_USERNAME")
         SOURCE_DB_PASSWORD=$(ask "Remote server database password" "$SOURCE_DB_PASSWORD")
      else
         SOURCE_HOST=''
         SOURCE_DATA_PATH=''
         SOURCE_SRC_PATH=''
         SOURCE_DB_NAME=''
         SOURCE_DB_USERNAME=''
         SOURCE_DB_PASSWORD=''
      fi
      echo
      echo "${ul}Box.com Configuration$rmul"
      echo
      echo 'If you want to use Box.com for online backups, please provide the following'
      echo 'information so you can point to a Box.com folder.'
      echo
      default_answer=n
      if [[ -n $BOX_CLIENT_ID || -n $BOX_CLIENT_SECRET || -n $BOX_REDIRECT_URI || -n $BOX_FOLDER_ID ]]; then
         default_answer=y
      fi
      if yorn "Do you want to use Box.com for online backups?" "$default_answer"; then
         BOX_CLIENT_ID=$(ask "Client ID" "$BOX_CLIENT_ID")
         BOX_CLIENT_SECRET=$(ask "Client secret" "$BOX_CLIENT_SECRET")
         BOX_REDIRECT_URI=$(ask "Redirect URI" "$BOX_REDIRECT_URI")
         BOX_FOLDER_ID=$(ask "Folder ID" "$BOX_FOLDER_ID")
      else
         BOX_CLIENT_ID=''
         BOX_CLIENT_SECRET=''
         BOX_REDIRECT_URI=''
         BOX_FOLDER_ID=''
      fi
      echo
      env_file="$MDL_ENVS_DIR/$mname/.env"
      # Find any custom variables in the .env file that are not in the default list.
      variables=(
         ROOT_PASSWORD DB_NAME DB_USERNAME DB_PASSWORD MOODLE_HOST WWWROOT
         SOURCE_HOST SOURCE_DATA_PATH SOURCE_SRC_PATH SOURCE_DB_NAME SOURCE_DB_USERNAME SOURCE_DB_PASSWORD
         BOX_CLIENT_ID BOX_CLIENT_SECRET BOX_REDIRECT_URI BOX_FOLDER_ID
      )
      custom_vars=()
      other_vars=()
      while IFS='=' read -r key val; do
         key="${key//[[:space:]]/}"
         [[ -z "$key" ]] && continue || found=false
         for var in "${variables[@]}"; do
            [[ $key == "$var" ]] && found=true && break
         done
         if ! $found; then
            [[ "$key" =~ [a-z] ]] && other_vars+=("$key=$val") || custom_vars+=("$key")
         fi
      done < <(grep -E '^[a-zA-Z_0-9]+=' "$env_file")
      # Write the environment file with configurations.
      echo "# Configuration for Moodle environment: $mname" > "$env_file"
      for var in "${variables[@]}" "${custom_vars[@]}"; do
         [[ $var == SOURCE_HOST ]] && echo $'\n# Remote Source Server' >> "$env_file"
         [[ $var == BOX_CLIENT_ID ]] && echo $'\n# Box.com Backup' >> "$env_file"
         [[ $var == "${custom_vars[0]}" ]] && echo $'\n# Custom Configurations' >> "$env_file"
         echo "$var=${!var}" >> "$env_file"
      done
      if [[ ${#other_vars[@]} -gt 0 ]]; then
         echo $'\n# Other Variables' >> "$env_file"
         for var in "${other_vars[@]}"; do
            echo "$var" >> "$env_file"
         done
      fi
      echo "Saved configuration for $mname!"
      echo "It is saved at: $ul$env_file$rmul"
      echo
      if [[ -n $BOX_CLIENT_ID ]] && yorn 'Do you want to authenticate with Box.com?' y; then
         if ! "$scr_dir/mdl-box.sh" "$mname" auth; then
            echo "Box.com authentication failed. Please try again later with ${ul}mdl box$rmul." >&2
            exit 1
         fi
      fi
      # Instantiate environment with a starter Moodle environment/database.
      if $install_moodle; then
         # Get versions from version matrix, and ask user which version to install.
         versions=()
         versions_content=$(< "$MDL_VERSIONS_FILE")
         include_line=false
         while read -r line; do
            $include_line && versions+=("$line") || include_line=true
         done <<< "$versions_content"
         for ver_string in "${versions[@]}"; do
            IFS=' ' read -ra var_array <<< "$ver_string"
            branch_array+=("${var_array[0]}")
            moodle_array+=("$(echo "${var_array[1]}" | cut -d'.' -f1-2)")
         done
         PS3="Select the version to install: "
         select moodle_ver in "${moodle_array[@]}"; do
            if (( REPLY > 0 && REPLY <= ${#moodle_array[@]} )); then
               branchver=${branch_array[$REPLY - 1]}
               break
            else
               echo "Invalid selection. Please try again."
            fi
         done
         echo
         # Start the environment. Bitnami image will automatically bootstrap install. Wait to finish.
         branchver="$branchver" "$scr_dir/mdl-start.sh" "$mname" -q
         moodle_svc=$(container_tool ps --filter "label=com.docker.compose.project=$mname" --format '{{.Names}}' | grep moodle)
         src_vol_name=$(container_tool volume ls -q --filter "label=com.docker.compose.project=$mname" | grep src)
         # Do git install once standard install completes.
         function git_cmd() {
            container_tool run --rm -t --name "$mname-git-$(uuidgen)" -v "$src_vol_name":/git "$MDL_GIT_IMAGE" -c safe.directory=/git "$@"
         }
         (
            # Wait until standard bootstrap install completes.
            last_check=0
            until container_tool logs --since "$last_check" "$moodle_svc" 2>&1 | grep -q 'Moodle setup finished'; do
               last_check=$(($(date +%s)-1))
               sleep 5
            done
            #
            # We want to use Moodle's automatically-generated config.php file, but it creates the
            # configuration for $CFG->wwwroot like this:
            #
            # if (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] == 'on') {
            #   $CFG->wwwroot   = 'https://' . 'moodle_host';
            # } else {
            #   $CFG->wwwroot   = 'http://' . 'moodle_host';
            # }
            #
            # We don't want that. So we use awk to find the the block, and we replace it with just
            # a single line for `$CFG->wwwroot = 'moodle_host';` which will be easy to handle.
            #
            # shellcheck disable=SC2016
            awk_cmd='
               BEGIN { skip = 0 }
               /if *\(isset\(\$_SERVER\[.HTTPS.\]\) *&& *\$_SERVER\[.HTTPS.\] *== *'\''on'\''\) *{/ {
                  skip = 1; next
               }
               skip && /^\s*}\s*$/ {
                  skip = 0
                  print "$CFG->wwwroot   = '\'$WWWROOT\'';"
                  next
               }
               !skip { print }
            '
            config_file=/bitnami/moodle/config.php
            revised_config_file=$(mktemp)
            container_tool exec -it "$moodle_svc" awk "$awk_cmd" "$config_file" > "$revised_config_file"
            container_tool cp "$revised_config_file" "$moodle_svc":"$config_file"
            # Bitnami image unfortunately does not install the git repo. So, we add git after the fact.
            # This works fine since the Moodle repo branch will always be even with or slightly ahead of the Bitnami image.
            targetbranch="MOODLE_${branchver}_STABLE"
            git_cmd init -b main
            git_cmd remote add origin https://github.com/moodle/moodle.git
            git_cmd fetch -np origin "$targetbranch"
            git_cmd checkout -f "$targetbranch"
         ) > /dev/null &
         git_pid=$!
         yorn 'Do you want to optimize the git repository? It will save space but take more time.' 'n' && do_gc=true || do_gc=false
         echo -n 'Installing... '
         wait "$git_pid"
         echo 'Finished.'
         $do_gc && echo 'Optimizing git repository...' && git_cmd gc --prune=now --aggressive
         # The checkout will probably result in a slightly higher version, so we run an upgrade.
         echo "Upgrading to latest version of Moodle $moodle_ver.x..."
         "$scr_dir/mdl-cli.sh" "$mname" upgrade --non-interactive
         # After upgrades, we need to fix permissions.
         container_tool exec -it "${moodle_svc}" bash -c '
            chown -R daemon:daemon /bitnami/moodle /bitnami/moodledata
            chmod -R g+rwx /bitnami/moodle /bitnami/moodledata
         '
      fi
      echo 🎉 Done!
   else
      echo "Environment $ul$mname$rmul is already initialized!" >&2
      exit 1
   fi
fi
