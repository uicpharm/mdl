#!/bin/bash

. "${0%/*}/util/common.sh"

display_help() {
   cat <<EOF
Usage: $(script_name) <ENV> [key] [value]

Will issue a config get or set command for the Moodle environment. If you provide a key
but no value, it will ${ul}get$norm the value. If you provide the value, it will ${ul}set$norm the value.

If you do not provide a key/value pair, it will scan your environment file for valid keys
and set them. This is a convenient way to set all the keys in your environment file.

Since this command uses Moodle APIs, the environment must be started. If it isn't, the
command will exit.

Options:
-h, --help         Show this help message and exit.
EOF
}

[[ $* =~ -h || $* =~ --help ]] && display_help && exit

mnames=$("$scr_dir/select-env.sh" "$1")
key_param=$2
val_param=$3
[[ -n $key_param && -z $val_param ]] && get_mode=true || get_mode=false
cli="$scr_dir/cli.sh"

for mname in $mnames; do
   $get_mode || echo "$bold${ul}Setting configurations for $mname$norm"
   # The environment must be started. If not, abort.
   ! "$scr_dir/status.sh" "$mname" -q && echo "The $mname environment is not started!" >&2 && continue
   # If they provided a key, use that. Otherwise, use the contents of .env file.
   if [[ -z $key_param ]]; then
      env_file="$envs_dir/$mname/.env"
      [[ ! -f $env_file ]] && echo "The $mname .env file does not exist!" >&2 && exit 1
      env_content=$(cat "$env_file")
   else
      env_content="$key_param=$val_param"
   fi
   while IFS='=' read -r key value; do
      # Skip lines that are either empty or commented out (start with '#')
      if [ -z "$key" ] || [[ "$key" =~ ^[[:space:]]*# ]]; then
         continue
      fi
      # Skip keys that are not lowercase (Moodle configs are always lowercase)
      if [[ $key != $(echo "$key" | tr '[:upper:]' '[:lower:]') ]]; then
         continue
      fi
      # Only set it if cfg.php says it is a valid configuration key
      get_value=$($cli "$mname" cfg --name="$key" 2>/dev/null) && key_exists=true || key_exists=false
      if $key_exists && ! $get_mode; then
         # Remove surrounding quotes of the string in $value
         if [[ $value == \'*\' || $value == \"*\" ]]; then
            value="${value:1}"
            value="${value%?}"
         fi
         echo "$bold$key:$norm $value" >&2
         $cli "$mname" cfg --name="$key" --set="$value"
      elif $key_exists; then
         echo "$get_value"
      else
         echo "Skipped $key"
      fi
   done <<< "$env_content"
done
