#!/usr/bin/env bash

# helper function to quit script properly
quit() {
    # If the script is sourced, return instead of exit
    if [[ "${BASH_SOURCE[-1]}" != "${0}" ]]; then
        return "$0"
    else
        exit "$0"
    fi
}

# helper function to run a command and redirect stdout and stderr to separate files
# usage:
#   run <output_file> <error_file> <command> e.g.
#   run output.txt error.txt poetry run biaingest find new-biostudies-studies
run() {
  local out err
  out="$1"
  err="$2"
  shift 2

  "$@" \
    > >(tee -a "$out") \
    2> >(tee -a "$err" >&2)
}
