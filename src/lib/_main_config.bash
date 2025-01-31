# Filename: src/_main_config.bash
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

# shellcheck disable=SC2034
declare -gA config=(
    [LOG_LEVEL]="INFO"  # Default log level
    [LOG_TO_CONSOLE]=false  # Default: don't log to console
    [LOG_FORMAT]="json"
)
