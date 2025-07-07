#!/bin/bash

. "${0%/*}/../lib/mdl-common.sh"

display_help() {
   cat <<EOF
Usage: $(script_name) <ENV>

Initializes a Moodle environment and, if the system isn't initialized,
sets up the directories and configuration files for the system.

Options:
-h, --help         Show this help message and exit.
-f, --force        Force initialization even if already initialized.
    --no-title     Do not display the title banner.
EOF
}

[[ $* =~ -h || $* =~ --help ]] && display_help && exit
[[ $* =~ -f || $* =~ --force ]] && force=true || force=false
[[ $* =~ --no-title ]] && display_title=false || display_title=true

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
   echo 'Downloading compose file(s)...'
   if ! curl -fsL "$MDL_BASE_URL/compose/compose.yml" -o "$MDL_COMPOSE_DIR/compose.yml"; then
      echo "Failed to download compose file. Please check your internet connection or the URL." >&2
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
      "$scr_dir/mdl-touch-env.sh" "$mname"
      echo "Environment created at: $ul$MDL_ENVS_DIR/$mname$rmul"
      . "$scr_dir/mdl-export-env.sh" "$mname"
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
      echo 🎉 Done!
   else
      echo "Environment $ul$mname$rmul is already initialized!" >&2
      exit 1
   fi
fi
