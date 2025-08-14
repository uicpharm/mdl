#!/bin/bash

. "${0%/*}/../lib/mdl-common.sh"

display_help() {
   cat <<EOF
Usage: $(script_name) <ENV> [LABEL] [OPTIONS]

Deletes/removes files for a given Moodle environment. If you specify a backup label, it
will remove the backup set instead of the Moodle environment itself. If you specify the -e
or --env option, it will remove the entire Moodle environment, not just its data.

Options:
-h, --help         Show this help message and exit.
-e, --env          Remove the entire Moodle environment, not just its data.
-s, --sys          Fully uninstall the Moodle system.

$ul${bold}Examples$norm

Remove Moodle environment data:
   $bold$(script_name) \$mname$norm

Remove the entire Moodle environment:
   $bold$(script_name) \$mname --env$norm

Remove just this backup set for the Moodle environment:
   $bold$(script_name) \$mname 20240920$norm

Uninstall the entire Moodle system:
   $bold$(script_name) --sys$norm
EOF
}

# Parameter #1: Environment
if [[ $1 == -* ]]; then
   mnames=
else
   mnames=$("$scr_dir/mdl-select-env.sh" "$1")
   [[ $1 == all || $1 == "$mnames" ]] && shift
fi

# Parameter #2: Label, multiple can be provided
labels=
for arg in "$@"; do
   [[ $arg != -* ]] && labels+="$arg " && shift
done
labels="${labels%" "}"

[[ $* =~ -h || $* =~ --help ]] && display_help && exit
[[ $* =~ -e || $* =~ --env ]] && env=true || env=false
[[ $* =~ -s || $* =~ --sys ]] && sys=true || sys=false

requires "${MDL_CONTAINER_TOOL[0]}"

if $sys; then
   yorn "Remove backups at $ul$MDL_BACKUP_DIR$rmul?" y && rm -Rfv "$MDL_BACKUP_DIR"
   yorn "Remove Moodle environments at $ul$MDL_ENVS_DIR$rmul?" y && rm -Rfv "$MDL_ENVS_DIR"
   yorn "Remove compose files at $ul$MDL_COMPOSE_DIR$rmul?" y && rm -Rfv "$MDL_COMPOSE_DIR"
   yorn "Remove versions file at $ul$MDL_VERSIONS_FILE$rmul?" y && rm -fv "$MDL_VERSIONS_FILE"
   yorn "Remove config file at $ul$MDL_CONFIG_FILE$rmul?" y && rm -fv "$MDL_CONFIG_FILE"
   yorn "Remove the entire Moodle system at $ul$MDL_ROOT$rmul?" y && rm -Rfv "$MDL_ROOT"
   echo "Moodle system uninstalled successfully."
   exit 0
fi

for mname in $mnames; do

   if [ -n "$labels" ]; then
      # Remove a backup by environment/label
      for label in $labels; do
         echo "Removing backup for $mname with label $label..."
         for file_type in src data db dbfiles; do
            rm -fv "$MDL_BACKUP_DIR/${mname}_${label}_${file_type}".*
         done
      done
   else
      # Remove a moodle environment
      echo "Removing data for $mname environment..."
      vols=$(container_tool volume ls -q --filter "label=com.docker.compose.project=$mname")
      db_vol_name=$(grep db <<< "$vols")
      data_vol_name=$(grep data <<< "$vols")
      src_vol_name=$(grep src <<< "$vols")
      [ -n "$db_vol_name" ] && echo "Clearing the database volume... $(container_tool volume rm "$db_vol_name")"
      [ -n "$data_vol_name" ] && echo "Clearing the data volume... $(container_tool volume rm "$data_vol_name")"
      [ -n "$src_vol_name" ] && echo "Clearing the source volume... $(container_tool volume rm "$src_vol_name")"
      if $env; then
         echo "Removing the entire $mname environment itself..."
         rm -Rf "${MDL_ENVS_DIR:?}/${mname:?}"
      fi
   fi
done
