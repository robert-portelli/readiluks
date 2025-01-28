# Filename: lib/arg_parse.bash
# Description:
# Purpose:
# Options:
# Usage:
# Example(s):
# Requirements:
# Author:
#   Robert Portelli
#   Repository: https://github.com/robert-portelli/readiluks
# Version:
#   See repository tags or release notes.
# License:
#   See repository license file (e.g., LICENSE.md).
# Last Updated:
#   See repository commit history (e.g., `git log`).

# Parse arguments to set log level, log-to-console option, and bats flags
parse_arguments() {
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --log-level)
                shift
                if [[ -n "$1" ]] && [[ "${LOG_LEVELS[$1]}" ]]; then
                    # shellcheck disable=SC2153
                    config[LOG_LEVEL]="$1"
                    shift
                else
                    echo "Invalid log level: $1. Valid options are: DEBUG, INFO, WARNING, ERROR."
                    exit 1
                fi
                ;;
            --log-to-console)
                config[LOG_TO_CONSOLE]=true
                shift
                ;;
            --bats-flags)
                shift
                if [[ -n "$1" ]]; then
                    # shellcheck disable=SC2034
                    config[BATS_FLAGS]="$1"
                    shift
                else
                    echo "Error: No flags provided after --bats-flags."
                    exit 1
                fi
                ;;
            --help|-h)
                echo "Usage: $0 [--log-level {DEBUG|INFO|WARNING|ERROR}] [--log-to-console] [--bats-flags '<flags>']"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Usage: $0 [--log-level {DEBUG|INFO|WARNING|ERROR}] [--log-to-console] [--bats-flags '<flags>']"
                exit 1
                ;;
        esac
    done
}
