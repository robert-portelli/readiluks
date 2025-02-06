# Filename: src/lib/parse_prod_args.bash
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
            --log-format)
                shift
                # ensure the default is set
                # shellcheck disable=SC2153
                config[LOG_FORMAT]="${config[LOG_FORMAT]:-json}"

                # normalize the flag before matching
                local log_format
                log_format=$(echo "$1" | tr '[:upper:]' '[:lower:]')

                case "$log_format" in
                    json|human)
                        config[LOG_FORMAT]="$log_format"
                        echo "LOG_FORMAT=${config[LOG_FORMAT]}"  # for integration testing
                        shift
                        ;;
                    *)
                        echo "ERROR: Invalid value for --log-format: '$1'. Must be 'json' or 'human'." >&2
                        exit 1
                        ;;
                esac
                ;;
            --log-level)
                shift
                if [[ -n "$1" ]] && [[ "${LOG_LEVELS[$1]}" ]]; then
                    # shellcheck disable=SC2153
                    config[LOG_LEVEL]="$1"
                    echo "LOG_LEVEL=${config[LOG_LEVEL]}" >&2  # for integration testing
                    shift
                else
                    echo "Invalid log level: $1. Valid options are: DEBUG, INFO, WARNING, ERROR." >&2
                    return 1
                fi
                ;;
            --log-to-console)
                config[LOG_TO_CONSOLE]=true
                echo "LOG_TO_CONSOLE=${config[LOG_TO_CONSOLE]}" >&2 # for integration testing
                shift
                ;;
            --device-uuid)
                shift
                if [[ -n "$1" ]] && blkid -U "$1" >/dev/null 2>&1; then
                    config[DEVICE_UUID]="$1"
                    echo "DEVICE_UUID=${config[DEVICE_UUID]}" >&2  # for integration testing
                    shift
                else
                    echo "ERROR: UUID not found: '$1'" >&2
                    return 1
                fi
                ;;
            --device-label)
                shift
                if [[ -n "$1" ]] && [[ -e "/dev/disk/by-partlabel/$1" ]]; then
                    config[DEVICE_LABEL]="$1"
                    echo "DEVICE_LABEL=${config[DEVICE_LABEL]}" >&2  # for integration testing
                    shift
                else
                    echo "ERROR: Device label not found: '$1'" >&2
                    return 1
                fi
                ;;
            --help|-h)
                usage_message
                return 0
                ;;
            *)
                echo "Unknown option: $1"
                usage_message >&2
                return 1
                ;;
        esac
    done
    return 0
}

usage_message() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --log-level {DEBUG|INFO|WARNING|ERROR}  Set log verbosity level.
  --log-to-console                        Enable console logging.
  --log-format {json|human}               Set log format.
  --device-uuid <UUID>                    Specify device UUID (e.g., "12345678-1234-5678-1234-567812345678").
  --device-label <LABEL>                  Specify device label (e.g., "/dev/disk/by-partlabel/example-device").
  --help, -h                              Show this help message and exit.

EOF
}



log_config() {
    if [[ "$(declare -p config 2>/dev/null)" =~ "declare -A" ]]; then
        for key in "${!config[@]}"; do
            lm DEBUG "config[$key] = ${config[$key]}"
        done
    else
        lm ERROR "config is not defined or not an associative array."
    fi
}
