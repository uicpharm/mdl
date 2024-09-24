#!/bin/bash

. "${0%/*}/util/common.sh"

display_help() {
   cat <<EOF
Usage: $(script_name) <ENV>

Finds an environment's ${ul}config.php$rmul file and updates it with the values found in the
environment's $ul.env$rmul file.

Options:
-h, --help      Show this help message and exit.
EOF
}

[[ $* =~ -h || $* =~ --help ]] && display_help && exit

mnames=$("$scr_dir/select-env.sh" "$1")

for mname in $mnames; do

   env_dir="$scr_dir/environments/$mname"
   src_path="$env_dir/src"
   # shellcheck source=environments/sample.env
   "$scr_dir/touch-env.sh" "$mname" && source "$env_dir/../blank.env" && source "$env_dir/.env"

   # Get desired wwwroot value
   if [ -z "$WWWROOT" ]; then
      defaultwwwroot="$(grep -o -E "CFG->wwwroot\s*=\s*'(.*)';" "$src_path/config.php" | cut -d"'" -f2)"
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

   # If config.php does not exist, skip the rest of this
   [ ! -f "$src_path/config.php" ] && continue

   # Replace values in config
   sed -i -e "/'dbport'/ s/> .*,/> 3306,/" "$src_path/config.php"
   sed -i -e "/CFG->dbhost/ s/'.*'/'mariadb'/" "$src_path/config.php"
   sed -i -e "/CFG->dbname/ s/'.*'/'$DB_NAME'/" "$src_path/config.php"
   sed -i -e "/CFG->dbuser/ s/'.*'/'$DB_USERNAME'/" "$src_path/config.php"
   sed -i -e "/CFG->dbpass/ s/'.*'/'$DB_PASSWORD'/" "$src_path/config.php"
   sed -i -e "/CFG->wwwroot/ s|'.*'|'$WWWROOT'|" "$src_path/config.php"
   sed -i -e "/CFG->dataroot/ s/'.*'/'\/bitnami\/moodledata'/" "$src_path/config.php"
   [ -n "$CPE_MONITOR_WEBSERVICE_URL" ] && sed -i -e "/CFG->webserviceurl/ s|'.*'|'$CPE_MONITOR_WEBSERVICE_URL'|" "$src_path/config.php"
   [ -n "$CPE_MONITOR_USERNAME" ] && sed -i -e "/CFG->webserviceusername/ s|'.*'|'$CPE_MONITOR_USERNAME'|" "$src_path/config.php"
   [ -n "$CPE_MONITOR_PASSWORD" ] && sed -i -e "/CFG->webservicepassword/ s|'.*'|'$CPE_MONITOR_PASSWORD'|" "$src_path/config.php"

   # Remove the backup file that sed creates
   rm -f "$src_path/config.php-e"

done
