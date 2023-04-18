#!/bin/bash

scr_dir="${0%/*}"
"$scr_dir/cli.sh" "$1" reset_password "${@:2}"
