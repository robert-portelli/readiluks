# Filename: src/lib/log_prod_output.bash
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
declare -A LOG_LEVELS=(
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
