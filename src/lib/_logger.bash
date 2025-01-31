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

# Define log levels
declare -gA LOG_LEVELS=(
    [DEBUG]=0
    [INFO]=1
    [WARNING]=2
    [ERROR]=3
)

# Log message function
lm() {
    local level=$1
    local message=$2

    # shellcheck disable=SC2153
    if (( LOG_LEVELS[$level] >= LOG_LEVELS[$LOG_LEVEL] )); then
        logger -t "readiluks-$level" "$message"
        if [[ "$LOG_TO_CONSOLE" == true ]]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
        fi
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
