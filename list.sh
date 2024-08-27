#!/bin/bash

scr_dir="${0%/*}"
backup_dir="$scr_dir/backup"

# Formatting
norm="$(tput sgr0)"
ul="$(tput smul)"
bold="$(tput bold)"

# Defaults
quiet=false
type='backup fastdb' # Word list of types

# Help
display_help() {
   cat <<EOF
Usage: ${0##*/} <ENV> [OPTIONS]

List available backups.

Options:
-h, --help      Show this help message and exit.
-q, --quiet     Only list backup labels without pretty formatting.
-t, --type      The type of backups to list (${ul}backup$norm or ${ul}fastdb$norm).
EOF
}

# Handle the first parameter, which should be the env (If not provided, assume "all").
if [[ $1 == -* || -z "$1" ]]; then
   mnames=$("$scr_dir/select-env.sh" all)
else
   mnames=$("$scr_dir/select-env.sh" "$1")
   shift
fi

# Collect optional arguments
while getopts hqt:-: OPT; do
   # Support long options. Ref: https://stackoverflow.com/a/28466267/519360
   if [ "$OPT" = "-" ]; then
      OPT="${OPTARG%%=*}"       # extract long option name
      OPTARG="${OPTARG#"$OPT"}" # extract long option argument (may be empty)
      OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
   fi
   case "$OPT" in
      q | quiet) quiet=true ;;
      # They can pass multiple type values as "one two" or "one,two". We sub "," to " ".
      t | type) type="${OPTARG//,/ }" ;;
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
# Validate that type is "backup" or "fastdb". Any other value is invalid.
for t in $type; do
   [[ $t != 'backup' && $t != 'fastdb' ]] && >&2 echo "Error: Invalid backup type $ul$t$norm." && exit 1
done

$quiet && list_prefix='' || list_prefix='  - '
[[ $type == *backup* ]] && type_backup=true || type_backup=false
[[ $type == *fastdb* ]] && type_fastdb=true || type_fastdb=false

for mname in $mnames; do
   # Only display environment name when we're actually displaying multiple
   if [[ $quiet == false && $(echo "$mnames" | wc -w) -gt 1 ]]; then
      echo -e "\n${ul}Environment: $bold$mname$norm"
   fi

   # Collect the list of backups
   $type_backup && labels="$(find "$backup_dir" -name "${mname}_*_src.*" | cut -d"_" -f2- | sed -e "s/_src\..*//" | uniq | sort)"
   $type_fastdb && fast_labels=$(find "$backup_dir" -name "${mname}_*_dbfiles.tar" | cut -d"_" -f2- | sed -e "s/_dbfiles.tar//" | sort)

   # Output: Normal Backups
   if $type_backup && ! $quiet; then
      echo -n "Backups: "
      [ -z "$labels" ] && echo 'none' || echo
   fi
   for label in $labels; do
      echo "$list_prefix$label"
   done

   # Output: Fast Database Backups
   $type_fastdb && ! $quiet && [ -n "$fast_labels" ] && echo "Fast Database Backups:"
   for label in $fast_labels; do
      echo "$list_prefix$label"
   done

done
