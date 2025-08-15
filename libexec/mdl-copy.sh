#!/bin/bash

. "${0%/*}/../lib/mdl-common.sh"

# Valid Options
valid_modules='src data db'
valid_type='backup fastdb'

# Defaults
type='backup fastdb'
modules='src data db'
remove=false
box=false
dry_run=false
verbose=false

# Help
display_help() {
   cat <<EOF
Usage: $(script_name) <ENV> <LABEL> [DEST] [OPTIONS]

Copies a Moodle backup from the local environment to another destination. This
can include a local system path, a remote server via scp, or even Box.com.

Options:
-h, --help      Show this help message and exit.
-t, --type      The type of backup to copy. ($(echo "${valid_type}" | sed "s/ /, /g" | sed "s/\([^, ]*\)/${ul}\1$norm/g"))
-m, --modules   Which module to copy. ($(echo "${valid_modules}" | sed "s/ /, /g" | sed "s/\([^, ]*\)/${ul}\1$norm/g"))
-l, --label     Label to rename the new copy.
-r, --rm        Remove the source backup after copying.
-b, --box       Copy the backup to Box using credentials stored in .env file.
-n, --dry-run   Show what would've happened without executing.
-v, --verbose   Provide more verbose output.
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

# Positional parameter #2: Label
if [[ $1 == -* || -z $1 ]]; then
   echo -e "${red}You MUST provide the backup label to copy.$norm\n" >&2
   display_help; exit 1;
else
   label="$1"
   shift
fi

# Positional parameter #3: Destination
if [[ $1 != -* && -n $1 ]]; then
   dest=$(realpath "$1") || exit 1
   shift
fi

# Collect optional arguments.
# shellcheck disable=SC2214
# spellchecker: disable-next-line
while getopts hrbvnl:t:m:-: OPT; do
   support_long_options
   case "$OPT" in
      h | help)
         display_help
         exit 0
         ;;
      r | rm) remove=true ;;
      b | box) box=true ;;
      v | verbose) verbose=true ;;
      n | dry-run) dry_run=true ;;
      t | type) type="${OPTARG//,/ }" ;;
      l | label) new_label=$OPTARG ;;
      m | modules) modules=$(echo "${OPTARG//,/ }" | tr '[:upper:]' '[:lower:]') ;;
      \?) echo "${red}Invalid option: -$OPT$norm" >&2 ;;
      *) echo "${red}Some of these options are invalid:$norm $*" >&2; exit 2 ;;
   esac
done
shift $((OPTIND - 1))

#
# Calculations
#

# Clear the modules if type doesn't include "backup"
[[ $type != *backup* ]] && modules=''

#
# Validation
#

requires realpath find

# Must either have a valid destination or indicate "box" flag.
if [[ -z $dest ]] && ! $box; then
   echo "${red}${bold}You MUST provide a destination or send to Box with $ul--box$norm." >&2
   exit 1
fi

# If destination, it must be valid
if [[ -n $dest ]]; then
   dest=$(realpath "$dest") || exit 1
fi

# Only valid modules
for m in $modules; do
   if [[ ! "$valid_modules" =~ $m ]]; then
      echo -e "${red}${bold}Invalid module type: $m.$norm\n" >&2
      exit 1
   fi
done

# Only valid types
for t in $type; do
   if  [[ ! "$valid_type" =~ $t ]]; then
      echo  -e  "${red}${bold}Invalid type of backup to copy: $t.$norm\n" >&2
      exit 1
   fi
done

for mname in $mnames; do

   # Collect list of applicable files
   files=()
   [[ $type =~ fastdb ]] && fastdb_modules='dbfiles'
   desired_modules="$modules $fastdb_modules"
   for m in $desired_modules; do
      while IFS= read -r -d '' file; do
         files+=( "$file" )
      done < <(find "$MDL_BACKUP_DIR" -name "${mname}_${label}_$m.*" -print0)
   done

   #
   # Per environment validation
   #

   # Some source files must be found
   if [[ ${#files[@]} -eq 0 ]]; then
      echo "${red}${bold}No backups were found for $mname with label $ul$label$rmul.$norm" >&2
      exit 1
   fi

   $box && dest_readable="Box.com" || dest_readable="destination"
   if $verbose; then
      echo "${ul}${bold}Copying $mname backup $label to $dest_readable$norm"
      echo
      [[ -n $type ]] && echo "${bold}  Types:$norm $type"
      [[ -n $modules ]] && echo "${bold}Modules:$norm $modules"
      [[ -n $new_label ]] && echo "${bold} Rename:$norm $new_label"
      [[ -n $dest ]] && echo "${bold}   Dest:$norm $dest"
      $box && echo "${bold}   Dest:$norm Box.com"
      echo "${bold} Remove:$norm $remove (after successful copy)"
      echo
   fi

   for file in "${files[@]}"; do
      filename=$(basename "$file")
      # Handle renaming label
      if [[ -n $new_label ]] && [[ $label != "$new_label" ]]; then
         new_filename=$(sed -E 's/([^_]+)_[^_]+_([^_]+)([.\w]+)/\1_'"$new_label"'_\2\3/' <<< "$filename")
      else
         new_filename=$filename
      fi
      # If destination is same as source, nothing to do here!
      if [[ $file == "$dest/$new_filename" ]]; then
         echo "${red}File $ul$file$rmul skipped because it is same as source." >&2
         continue
      fi
      # Copy is different based on Box upload or filesystem copy
      if $box; then
         cmd="$scr_dir/mdl-box.sh $mname upload '$file' '$new_filename'"
         $verbose && cmd="$cmd -v"
         success_msg="$file → Box.com/$new_filename"
      else
         cmd="cp '$file' '$dest/$new_filename'"
         success_msg="$file → $dest/$new_filename"
      fi
      $remove && cmd="$cmd && rm '$file'"
      $verbose && echo "$cmd"
      if $dry_run; then
         echo "${red}Copy of $ul$filename$rmul skipped because this is a dry run.$norm"
      else
         eval "$cmd" && echo "$success_msg"
      fi
   done

done
