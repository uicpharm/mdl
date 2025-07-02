#!/bin/bash

. "${0%/*}/../lib/mdl-common.sh"

# Defaults
update_config=true
unset_mode=false

# Help
display_help() {
   cat <<EOF
Usage: $(script_name) <ENV>

Handles all the tasks of setting or unsetting values from $ul.env$rmul so they can be used
by other scripts. For thoroughness, this includes doing the initial touch of the .env
file, clearing out existing values, loading the new values, and updating the environment's
${ul}config.php$rmul with the corresponding values.

Options:
-h, --help               Show this help message and exit.
-u, --unset              Unset all values in .env, instead of setting them.
    --no-update-config   Don't update the environment's config.php with new values.
EOF
}

# Positional parameter #1: Environment
if [[ $1 == -* || -z $1 ]]; then
   [[ $1 == -h || $1 == --help ]] || echo -e "${red}You MUST provide the environment.$norm\n" >&2
   display_help; exit 1;
else
   mname=$("$scr_dir/mdl-select-env.sh" "$1" --no-all)
   shift
fi

# Collect optional arguments.
# shellcheck disable=SC2214
# spellchecker: disable-next-line
while getopts hu-: OPT; do
   support_long_options
   case "$OPT" in
      h | help) display_help; exit 0 ;;
      no-update-config) update_config=false ;;
      u | unset) unset_mode=true ;;
      \?) echo "${red}Invalid option: -$OPT$norm" >&2 ;;
      *) echo "${red}Some of these options are invalid:$norm $*" >&2; exit 2 ;;
   esac
done
shift $((OPTIND - 1))

$unset_mode && update_config=false
env_dir="$MDL_ENVS_DIR/$mname"

export mname

# We touch the .env file before we look at it.
"$scr_dir/mdl-touch-env.sh" "$mname"

# Clear all known vars to proactively avoid data leaks.
variables=(
   ROOT_PASSWORD DB_NAME DB_USERNAME DB_PASSWORD MOODLE_HOST WWWROOT
   SOURCE_HOST SOURCE_DATA_PATH SOURCE_SRC_PATH SOURCE_DB_NAME SOURCE_DB_USERNAME SOURCE_DB_PASSWORD
   BOX_CLIENT_ID BOX_CLIENT_SECRET BOX_REDIRECT_URI BOX_FOLDER_ID
)
for var in "${variables[@]}"; do
   unset "$var"
done

# Set or unset this env data. Only look at UPPERCASE keys.
# shellcheck disable=SC2046
if $unset_mode; then
   unset $(grep -E '^[A-Z_0-9]+=' "$env_dir/.env" | cut -d= -f1 | xargs)
else
   export $(grep -E '^[A-Z_0-9]+=' "$env_dir/.env" | xargs)
fi

# Update configs in environment's config.php file.
if $update_config; then
   env_config_file="$env_dir/src/config.php"

   # Get desired wwwroot value
   if [ -z "$WWWROOT" ]; then
      defaultwwwroot="$(grep -o -E "CFG->wwwroot\s*=\s*'(.*)';" "$env_config_file" | cut -d"'" -f2)"
      altwwwroot1="http://$HOSTNAME"
      [ "$defaultwwwroot" = "$altwwwroot1" ] && altwwwroot1=''
      altwwwroot2="http://$MOODLE_HOST"
      [ "$defaultwwwroot" = "$altwwwroot2" ] && altwwwroot2=''
      echo 'You can avoid this prompt by setting WWWROOT in your .env file.'
      PS3="Select a desired wwwroot value or type your own: "
      select WWWROOT in "$defaultwwwroot" $altwwwroot1 $altwwwroot2; do
         WWWROOT="${WWWROOT:-$REPLY}"
         break
      done
   fi

   replace_config_value() {
      local content="$1"
      [[ -t 0 ]] && shift || content="$(cat)"
      local key="$1"
      local val="$2"
      echo "$content" | sed -E "s|(\\\$CFG->${key}[[:space:]]*=[[:space:]]*'?)[^';]*('?;)|\1${val}\2|g"
   }

   # Replace values in config
   if [[ -f "$env_config_file" ]]; then
      # Standard updates
      config_content=$(
         sed -E "/'dbport'/ s/> .*,/> 3306,/" "$env_config_file" |
         replace_config_value dbtype "${DB_TYPE:-mariadb}" |
         replace_config_value dbhost "${DB_HOST:-mariadb}" |
         replace_config_value dbname "$DB_NAME" |
         replace_config_value dbuser "$DB_USERNAME" |
         replace_config_value dbpass "$DB_PASSWORD" |
         replace_config_value wwwroot "$WWWROOT" |
         replace_config_value dataroot "${DATA_ROOT:-/bitnami/moodledata}"
      )
      # Run custom updates if provided
      custom_script="$env_dir/custom-config.sh"
      # shellcheck disable=SC1090
      [[ -f $custom_script ]] && config_content=$(. "$custom_script" "$config_content")
      # Write new contents to config file
      [[ -n $config_content ]] && echo "$config_content" > "$env_config_file"
   fi
fi
