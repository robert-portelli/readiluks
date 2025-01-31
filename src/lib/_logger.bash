# Filename: src/lib/_logger.bash
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

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Define log levels
source "$BASE_DIR/src/lib/_log_levels.bash"

# Log message function
lm() {
    local level=$1
    local message=$2
    local timestamp log_entry

    # shellcheck disable=SC2153
    if (( LOG_LEVELS[$level] >= LOG_LEVELS[$LOG_LEVEL] )); then
        # shellcheck disable=SC2154
        case "${config[LOG_FORMAT]}" in
            json)
                timestamp="$(date --iso-8601=seconds)"
                log_entry="{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"message\":\"$message\"}"
                logger -t "readiluks-$level" -- "$log_entry"
            ;;
            human)
                log_entry="[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
                logger -t "readiluks-$level" -- "$log_entry"
            ;;
        esac

        [[ "$LOG_TO_CONSOLE" == true ]] && echo "$log_entry"
    fi
}

log_config() {
    if [[ "$(declare -p CONFIG 2>/dev/null)" =~ "declare -A" ]]; then
        for key in "${!CONFIG[@]}"; do
            lm DEBUG "CONFIG[$key] = ${CONFIG[$key]}"
        done
    else
        lm ERROR "CONFIG is not defined or not an associative array."
    fi
}
