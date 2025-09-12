#!/bin/bash

#
# These are functions that help with formatting of data, whether it be pretty
# for humans or machine-readable like JSON or INI.
#

# Prints a formatted line, with bolded label, value, and optional bool at end.
# If only label is provided, will format it as an underlined heading.
# - $1: The label to display (bolded)
# - $2: The value to display
# - $3: A boolean indicating success or failure (optional)
function pretty_line () {
   local out
   out=$(tput bold) && [[ -z $2 ]] && out=$out$(tput smul)
   out="$out$1${2+:}$(tput sgr0) $2 ${3+$(pretty_bool "$3")}"
   echo "$out"
}

# Prints a boolean value as a checkbox or red X
function pretty_bool () {
   $1 && echo ✅ || echo ❌
}

# Output a list of fields as INI `key=value` pairs
function make_ini () {
   for var in "$@"; do
      echo "$var=${!var}"
   done
}

# Output a list as a bash array, like `( "one" "two" "three" )`.
function make_ini_array () {
   echo -n "( "
   for val in "$@"; do
      echo -n "\"$val\" "
   done
   echo -n ")"
}

# Output a list of fields as a JSON object. Will take values that look like
# booleans, numbers, or arrays and format them accordingly.
function make_json () {
   local first=true
   local var
   echo -n "{"
   for var in "$@"; do
      $first && first=false || echo -n ","
      # Do not escape quotes for arrays, which are strings already formatted as an array for json
      local val="${!var//\"/\\\"}" && [[ $val =~ ^\[.*\]$ ]] && val=${!var}
      local q="\"" && [[ $val =~ ^[0-9]+$ || $val =~ ^(true|false)$ || $val =~ ^\[.*\]$ ]] && q=
      echo -n " \"${var}\": $q$val$q"
   done
   echo " }"
}

# Output a list of values as a JSON array, like `[ 1, 2, "three" ]`.
function make_json_array () {
   local first=true
   local item
   echo -n "["
   for item in "$@"; do
      $first && first=false || echo -n ","
      local val="${item//\"/\\\"}"
      # Do not wrap quotes around numbers, booleans, or arrays
      local q="\"" && [[ $val =~ ^[0-9]+$ || $val =~ ^(true|false)$ || $val =~ ^\[.*\]$ ]] && q=
      echo -n "$q$val$q"
   done
   echo -n "]"
}
