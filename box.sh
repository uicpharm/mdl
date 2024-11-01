#!/bin/bash

. "${0%/*}/util/common.sh"

# Validation
valid_action='auth refresh list ls download upload'

# Defaults
file=''
action=''
json=false
verbose=false

# Help
display_help() {
   cat <<EOF
Usage: $(script_name) <ENV> <ACTION> [file] [dest]

Handles file access to Box.com as online storage for backups.

Actions:
$(for a in $valid_action; do echo "  - $a"; done)

Options:
-h, --help      Show this help message and exit.
-v, --verbose   Provide more verbose output.

Options for list/ls:
-j, --json      Output results as JSON.
EOF
}

# Positional parameter #1: Environment
if [[ $1 == -* || -z $1 ]]; then
   [[ $1 == -h || $1 == --help ]] || echo -e "${red}You MUST provide the environment.$norm\n" >&2
   display_help; exit 1;
else
   mnames=$("$scr_dir/select-env.sh" "$1")
   shift
fi

# Positional parameter #2: Action
if [[ $1 == -* || -z $1 ]]; then
   echo -e "${red}You MUST provide an action to perform.$norm\n" >&2
   display_help; exit 1;
else
   action="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
   shift
fi

# Positional parameter #3: File
if [[ $1 != -* && -n $1 ]]; then
   file=$1
   shift
fi

# Positional parameter #4: Target
if [[ $1 != -* && -n $1 ]]; then
   targ=$1
   shift
fi

# Collect optional arguments.
# shellcheck disable=SC2214
# spellchecker: disable-next-line
while getopts hjvn-: OPT; do
   support_long_options
   case "$OPT" in
      h | help) display_help; exit 0 ;;
      j | json) json=true ;;
      v | verbose) verbose=true ;;
      \?) echo "${red}Invalid option: -$OPT$norm" >&2 ;;
      *) echo "${red}Some of these options are invalid:$norm $*" >&2; exit 2 ;;
   esac
done
shift $((OPTIND - 1))

#
# Validation
#

# Requires curl and jq utilities
if [[ -z $(which curl) ]] || [[ -z $(which jq) ]]; then
   echo "${red}${bold}This command requires ${ul}curl$rmul and ${ul}jq$rmul to work.$norm" >&2
   exit 1
fi

# Only valid actions
if [[ ! "$valid_action" =~ $action ]]; then
   echo -e "${red}${bold}Invalid action: $action.$norm\n" >&2
   exit 1
fi

# Must provide valid file for "upload" action
if [[ $action == upload ]]; then
   [[ -z $file ]] && echo "${red}${bold}For ${ul}upload$rmul action, you must provide a file.$norm" >&2 && exit 1
   file=$(realpath "$file") || exit 1 # It must be a real file with full path
fi

if [[ $action == download ]]; then
   # Must provide a file for "download" action
   [[ -z $file ]] && echo "${red}${bold}For ${ul}download$rmul action, you must provide a file or file ID.$norm" >&2 && exit 1
   # Must provide a valid target for "download" action
   [[ -z $targ ]] && echo "${red}${bold}For ${ul}download$rmul action, you must provide a target destination for the file.$norm" >&2 && exit 1
fi

# This function handles the process of calling curl on the Box.com API, with
# detection of token failure, initiating a token refresh and reattempt of the
# API call.
function curl_api {
   local -r mname="$1"
   local -r args="$2"
   local -r access_token_file="$scr_dir/environments/$mname/access_token.txt"
   local access_token
   access_token=$(cat "$access_token_file" 2>/dev/null || echo invalid_token)
   response=$(eval "curl $args -H 'Authorization: Bearer $access_token'")
   # If response is empty (and -o was not in the args), or...
   # If response contains "invalid_token"...
   # Refresh the token and try again.
   if [[ ! $args == *"-o"* && -z $response ]] || echo "$response" | grep -q "invalid_token"; then
      $0 "$mname" refresh "$($verbose && echo '-v')"
      access_token=$(cat "$access_token_file" 2>/dev/null || echo 'invalid token')
      response=$(eval "curl $args -H 'Authorization: Bearer $access_token'")
   fi
   echo "$response"
}

for mname in $mnames; do

   # Get environment values and use them when no local value provided.
   # shellcheck source=environments/sample.env
   . "$scr_dir/export-env.sh" "$mname"

   #
   # Validation
   #

   # All Box environment variables must be set.
   for env_var in BOX_CLIENT_ID BOX_CLIENT_SECRET BOX_REDIRECT_URI BOX_FOLDER_ID; do
      [ -z "${!env_var}" ] && echo "${red}Your env file must have $ul$env_var$rmul set.$norm" >&2 && exit 1
   done

   access_token_file="$scr_dir/environments/$mname/access_token.txt"
   refresh_token_file="$scr_dir/environments/$mname/refresh_token.txt"

   if [[  $action == auth ]]; then
      echo "${bold}${ul}Authorizing with Box.com$norm"
      url="https://account.box.com/api/oauth2/authorize?response_type=code&client_id=$BOX_CLIENT_ID&redirect_uri=$BOX_REDIRECT_URI"
      echo "Go to the following link to get the authorization code:"
      echo "$ul$url$norm"
      [[ -n $(which open 2>/dev/null) ]] && open "$url"
      read -r -p "Authorization code: " auth_code
      if [[ -z $auth_code ]]; then
         echo "You entered a blank authorization code. Aborting."
      else
         response=$(curl -s -X POST "https://api.box.com/oauth2/token" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            -d "grant_type=authorization_code" \
            -d "client_id=$BOX_CLIENT_ID" \
            -d "client_secret=$BOX_CLIENT_SECRET" \
            -d "redirect_uri=$BOX_REDIRECT_URI" \
            -d "code=$auth_code")
         new_access_token=$(echo "$response" | jq -r '.access_token')
         new_refresh_token=$(echo "$response" | jq -r '.refresh_token')
         if [[ $new_access_token == null ]]; then
            echo "Failed to authorize. Aborting." >&2
            exit 1
         else
            echo "$new_access_token" > "$access_token_file"
            echo "$new_refresh_token" > "$refresh_token_file"
            echo "Authorization successful!"
         fi
      fi
   elif [[ $action == refresh ]]; then
      if $verbose; then echo "Refreshing authorization token..." >&2; fi
      refresh_token=$(cat "$refresh_token_file" 2>/dev/null)
      response=$(curl -s -X POST "https://api.box.com/oauth2/token" \
         -d "grant_type=refresh_token" \
         -d "client_id=$BOX_CLIENT_ID" \
         -d "client_secret=$BOX_CLIENT_SECRET" \
         -d "refresh_token=$refresh_token")
      new_access_token=$(echo "$response" | jq -r '.access_token')
      new_refresh_token=$(echo "$response" | jq -r '.refresh_token')
      if [[ $new_access_token == null ]]; then
         echo "Failed to refresh authorization token." >&2
         exit 1
      else
         echo "$new_access_token" > "$access_token_file"
         echo "$new_refresh_token" > "$refresh_token_file"
         if $verbose; then echo "Refresh successful!" >&2; fi
      fi
   elif [[ $action == upload ]]; then
      file_name=$(basename "$file")
      if $verbose; then echo "Uploading file $file"; fi
      # Check if this file already exists.
      file_id=$($0 "$mname" ls -j | jq -r --arg val "$file_name" '.entries[] | select(.name == $val) | .id')
      url="https://upload.box.com/api/2.0/files"
      [[ -n $file_id ]] && url="$url/$file_id" && $verbose && echo "$file_name exists with ID $file_id. Uploading new version."
      url="$url/content"
      curl_args="-X POST $url -F file=@'$file' -F attributes='{\"name\":\"$file_name\", \"parent\":{\"id\":\"$BOX_FOLDER_ID\"}}'"
      $verbose || cmd="$cmd -s"
      response=$(curl_api "$mname" "$curl_args")
      if [[ -n $response ]]; then
         msg=$(echo "$response" | jq -r '.message')
         if [[ $msg != null ]]; then
            echo "$red$msg$norm" >&2
            exit 1
         fi
         if $verbose; then echo "Successfully uploaded $file_name with ID $(echo "$response" | jq -r '.entries[] | .id')."; fi
      else
         echo "Failed to upload." >&2
         exit 1
      fi
   elif [[ $action == download ]]; then
      # Find the file. Search by name first, and if not found, search by ID.
      files_json=$($0 "$mname" ls -j)
      file_id=$(echo "$files_json" | jq -r --arg val "$file" '.entries[] | select(.name == $val) | .id')
      [[ -z $file_id ]] && file_id=$(echo "$files_json" | jq -r --arg val "$file" '.entries[] | select(.id == $val) | .id')
      [[ -z $file_id ]] && echo "${red}Could not find file $file.$norm" >&2 && exit 1
      curl_api "$mname" "-L https://api.box.com/2.0/files/$file_id/content -o $targ"
   elif [[ $action == list ]] || [[ $action == ls ]]; then
      if $verbose; then echo "${bold}${ul}Files for $mname:$norm"; fi
      url="https://api.box.com/2.0/folders/$BOX_FOLDER_ID/items?fields=id,name,type,sequence_id"
      curl_args="-s -X GET $url -H 'Content-Type: application/json'"
      response=$(curl_api "$mname" "$curl_args")
      if [[ -n $response ]]; then
         $json && echo "$response" | jq
         $json || echo "$response" | jq -r '.entries[] | .name' | grep -E "^$mname"
      else
         echo "Failed to retrieve files or folder is empty." >&2
         exit 1
      fi
   else
      echo "${red}Invalid action: $action.$norm" >&2
      exit 1;
   fi

done
