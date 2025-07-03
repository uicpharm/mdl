#!/bin/bash

. "${0%/*}/../lib/mdl-common.sh"

# Defaults
dry_run=false
verbose=false

# Help
display_help() {
   cat <<EOF
Usage: $(script_name) <ENV> <LABEL> <NEW_LABEL> [OPTIONS]

Renames a Moodle backup set with one label to another label. It targets all
associated files with the provided label.

Options:
-h, --help      Show this help message and exit.
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
   echo -e "${red}You MUST provide the backup label to rename.$norm\n" >&2
   display_help; exit 1;
else
   label="$1"
   shift
fi

# Positional parameter #3: New Label
if [[ $1 == -* || -z $1 ]]; then
   echo -e "${red}You MUST provide the new backup label to rename to.$norm\n" >&2
   display_help; exit 1;
else
   new_label="$1"
   shift
fi

# Collect optional arguments.
# shellcheck disable=SC2214
# spellchecker: disable-next-line
while getopts hvn-: OPT; do
   support_long_options
   case "$OPT" in
      h | help) display_help; exit 0 ;;
      v | verbose) verbose=true ;;
      n | dry-run) dry_run=true ;;
      \?) echo "${red}Invalid option: -$OPT$norm" >&2 ;;
      *) echo "${red}Some of these options are invalid:$norm $*" >&2; exit 2 ;;
   esac
done
shift $((OPTIND - 1))

for mname in $mnames; do

   while IFS= read -r -d '' file; do
      filename=$(basename "$file")
      new_filename=$(sed -E 's/([^_]+)_[^_]+_([^_]+)([.\w]+)/\1_'"$new_label"'_\2\3/' <<< "$filename")
      cmd="mv -v '$MDL_BACKUP_DIR/$filename' '$MDL_BACKUP_DIR/$new_filename'"
      $verbose && echo "$cmd"
      if $dry_run; then
         echo "${red}Rename $ul$filename$rmul → $ul$new_filename$rmul skipped because this is a dry run.$norm"
      else
         eval "$cmd"
      fi
   done < <(find "$MDL_BACKUP_DIR" -type f -print0 | grep -zE "/${mname}_${label}_(db|data|src|dbfiles)\.[[:alnum:].]+\$")

done
