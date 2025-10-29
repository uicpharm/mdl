#!/bin/bash

. "${0%/*}/../lib/mdl-common.sh"

# Defaults
upgrade=true

display_help() {
   cat <<EOF
Usage: $(script_name) <ENV> <PLUGIN_ZIP_FILES...> [OPTIONS]

Receives a list of zip files containing Moodle plugins, and installs them into the Moodle
environment. If the path to the zip file is a URL, it will be downloaded, but it must be a
publicly accessible URL.

Options:
-h, --help          Show this help message and exit.
-s, --skip-upgrade  Skip the Moodle upgrade after copying the plugin files.
EOF
}

[[ $* =~ -h || $* =~ --help ]] && display_help && exit

# Positional parameter #1: Environment
mnames=$("$scr_dir"/mdl-select-env.sh "$1")
shift

# Positional parameter #2 (and all remaining): Plugin zip files
zip_files=()
while [[ $# -gt 0 ]]; do
   case "$1" in
      -*) break ;; # Stop once we hit an option
      *) zip_files+=("$1"); shift ;;
   esac
done

# Collect optional arguments.
# shellcheck disable=SC2214
# spellchecker: disable-next-line
while getopts hs-: OPT; do
   support_long_options
   case "$OPT" in
      h | help) display_help; exit ;;
      s | skip-upgrade) upgrade=false ;;
      \?) echo "${red}Invalid option: -$OPT$norm" >&2 ;;
      *) echo "${red}Some of these options are invalid:$norm $*" >&2; exit 2 ;;
   esac
done
shift $((OPTIND - 1))

requires basename curl find jq grep head mktemp unzip xargs "${MDL_CONTAINER_TOOL[0]}"

# Calculate the plugin path based on type
function plugin_type_path() {
   case $1 in
      antivirus) echo lib/antivirus ;;
      assignsubmission) echo mod/assign/submission ;;
      assignfeedback) echo mod/assign/feedback ;;
      booktool) echo mod/book/tool ;;
      customfield) echo customfield/field ;;
      datafield) echo mod/data/field ;;
      datapreset) echo mod/data/preset ;;
      ltisource) echo mod/lti/source ;;
      fileconverter) echo files/converter ;;
      ltiservice) echo mod/lti/service ;;
      mlbackend) echo lib/mlbackend ;;
      forumreport) echo mod/forum/report ;;
      quiz) echo mod/quiz/report ;;
      quizaccess) echo mod/quiz/accessrule ;;
      scormreport) echo mod/scorm/report ;;
      workshopform) echo mod/workshop/form ;;
      workshopallocation) echo mod/workshop/allocation ;;
      workshopeval) echo mod/workshop/eval ;;
      block) echo blocks ;;
      qtype) echo question/type ;;
      qbehaviour) echo question/behaviour ;;
      qformat) echo question/format ;;
      editor) echo lib/editor ;;
      atto) echo lib/editor/atto/plugins ;;
      tool) echo admin/tool ;;
      logstore) echo admin/tool/log/store ;;
      availability) echo availability/condition ;;
      calendartype) echo calendar/type ;;
      message) echo message/output ;;
      format) echo course/format ;;
      dataformat) echo dataformat ;;
      profilefield) echo user/profile/field ;;
      coursereport) echo course/report ;;
      gradeexport) echo grade/export ;;
      gradeimport) echo grade/import ;;
      gradereport) echo grade/report ;;
      gradingform) echo grade/grading/form ;;
      mnetservice) echo mnet/service ;;
      search) echo search/engine ;;
      media) echo media/player ;;
      plagiarism) echo plagiarism ;;
      cachestore) echo cache/stores ;;
      cachelock) echo cache/locks ;;
      contenttype) echo contentbank/contenttype ;;
      h5plib) echo h5p/h5plib ;;
      qbank) echo question/bank ;;
      *) echo "$1" ;;
   esac
}

for mname in $mnames; do

   # Get the Moodle container for this environment
   container="$(container_tool ps -f "label=com.docker.compose.project=$mname" --format '{{.Names}}' | grep moodle | head -1)"
   [[ -z $container ]] && echo "${red}Could not find a container running Moodle for $ul$mname$rmul!$norm" >&2 && exit 1

   # Get Moodle base directory by inspecting the container mount
   base_dir=$(container_tool inspect "$container" | jq -r '.[] .Mounts[] | select(.Name != null and (.Name | contains("src"))) | .Destination')
   [[ -z $base_dir ]] && echo "${red}Could not determine Moodle base directory for $ul$mname$rmul!$norm" >&2 && exit 1

   # Prepare a temporary directory to do work
   tempdir=$(mktemp -d)
   temp_unzipped=$tempdir/unzipped
   temp_downloaded=$tempdir/downloaded
   temp_moodle=$tempdir$base_dir

   # Process each zip file
   for zip_file in "${zip_files[@]}"; do
      zip_filename=$(basename "$zip_file")
      # If the zip file is a URL, download it first
      if [[ $zip_file =~ ^https?:// ]]; then
         mkdir -p "$temp_downloaded"
         zip_url=$zip_file
         zip_file="$temp_downloaded/$zip_filename"
         echo "Downloading $zip_filename..."
         curl -sSL -o "$zip_file" "$zip_url" || { echo "Failed to download $zip_file" >&2; exit 1; }
      fi
      # Unzip the plugin, and copy its contents to its final destination
      mkdir -p "$temp_unzipped"
      unzip -o -qq -d "$temp_unzipped" "$zip_file" || { echo "Failed to unzip $zip_file" >&2; exit 1; }
      # We use the directory inside the unzipped archive to determine plugin type and name. There should
      # only be one directory, but we put safeguards in place to make sure.
      # Example: block_my_great_plugin -> type=block, name=my_great_plugin
      pkg_name=$(find "$temp_unzipped" -maxdepth 1 -mindepth 1 -type d -print0 | xargs -0 basename | head -n1)
      type=${pkg_name%%_*}
      name=${pkg_name#*_}
      dest="$(plugin_type_path "$type")/$name"
      echo "Installing $type plugin $name to $ul$dest$norm."
      mkdir -p "$temp_moodle/$dest"
      ( shopt -s dotglob && cp -R "$temp_unzipped/$pkg_name"/* "$temp_moodle/$dest" )
      # Clean up
      rm -Rf "$temp_unzipped" "$temp_downloaded"
   done
   # Copy all final work into the container
   while IFS= read -r -d '' dir; do
      container_tool cp -q "$dir" "$container:$base_dir"
   done < <(find "$temp_moodle" -mindepth 1 -maxdepth 1 -type d -print0)

   # Clean up
   rm -Rf "$tempdir"

   # If requested, run the Moodle upgrade
   if $upgrade; then
      echo "${green}${bold}Running Moodle upgrade for $ul$mname$rmul...$norm"
      "$scr_dir/mdl-cli.sh" "$mname" upgrade --non-interactive
   fi

done
