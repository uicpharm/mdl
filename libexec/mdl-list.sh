#!/bin/bash

. "${0%/*}/../lib/mdl-common.sh"

# Defaults
quiet=false
valid_type='backup fastdb box'
default_type='backup fastdb'
type=$default_type

# Help
display_help() {
   cat <<EOF
Usage: $(script_name) <ENV> [OPTIONS]

Lists available backup sets for a Moodle environment.

Options:
-h, --help      Show this help message and exit.
-b, --box       Add Box to the list of backups to list.
-q, --quiet     Only list backup labels without pretty formatting.
-t, --type      Type of backups to list, default: $ul${default_type// /$norm, $ul}$norm. ($ul${valid_type// /$norm, $ul}$norm)
EOF
}

# Handle the first parameter, which should be the env (If not provided, assume "all").
if [[ $1 == -* || -z "$1" ]]; then
   mnames=$("$scr_dir/mdl-select-env.sh" all)
else
   mnames=$("$scr_dir/mdl-select-env.sh" "$1")
   shift
fi

# Collect optional arguments.
# shellcheck disable=SC2214
while getopts hbqt:-: OPT; do # spellchecker: disable-line
   support_long_options
   case "$OPT" in
      q | quiet) quiet=true ;;
      # They can pass multiple type values as "one two" or "one,two". We sub "," to " ".
      t | type) type="${OPTARG//,/ }" ;;
      b | box) type="$type box" ;;
      h | help) display_help; exit 0 ;;
      \?) echo "Invalid option: -$OPT" >&2 ;;
      *) echo "$*" >&2; exit 2 ;;
   esac
done
shift $((OPTIND - 1))

# Validation

# Since quiet only returns the labels, its sensible that it can only return one env/type.
if $quiet && [[ $(echo "$type" | wc -w) -gt 1 || $(echo "$mnames" | wc -w) -gt 1 ]]; then
   >&2 echo "Error: When using $bold--quiet$norm, specify a single environment and a single type of backup."
   exit 1
fi
# Only accept valid types
for t in $type; do
   [[ ! $valid_type =~ $t ]] && >&2 echo "Error: Invalid backup type $ul$t$norm." && exit 1
done

$quiet && list_prefix='' || list_prefix='  - '
[[ $type == *backup* ]] && type_backup=true || type_backup=false
[[ $type == *box* ]] && type_box=true || type_box=false
[[ $type == *fastdb* ]] && type_fastdb=true || type_fastdb=false

for mname in $mnames; do
   # Only display environment name when we're actually displaying multiple
   if [[ $quiet == false && $(echo "$mnames" | wc -w) -gt 1 ]]; then
      echo -e "\n${ul}Environment: $bold$mname$norm"
   fi

   # Collect the list of backups
   $type_backup && labels="$(find "$MDL_BACKUP_DIR" -name "${mname}_*_src.*" -print0 | xargs -0 -r -n1 basename | extract_label "$mname" src | sort | uniq)"
   $type_box && box_labels="$("$scr_dir/mdl-box.sh" "$mname" ls | extract_label "$mname" src | sort | uniq)"
   $type_fastdb && fast_labels=$(find "$MDL_BACKUP_DIR" -name "${mname}_*_dbfiles.*" -print0 | xargs -0 -r -n1 basename | extract_label "$mname" dbfiles | sort | uniq)

   # Output: Normal Backups
   if $type_backup && ! $quiet; then
      echo -n "Backups: "
      [ -z "$labels" ] && echo 'none' || echo
   fi
   for label in $labels; do
      echo "$list_prefix$label"
   done

   # Output: Box Backups
   if $type_box && ! $quiet; then
      echo -n "Box: "
      [ -z "$box_labels" ] && echo 'none' || echo
   fi
   for label in $box_labels; do
      echo "$list_prefix$label"
   done

   # Output: Fast Database Backups
   $type_fastdb && ! $quiet && [ -n "$fast_labels" ] && echo "Fast Database Backups:"
   for label in $fast_labels; do
      echo "$list_prefix$label"
   done

done
