# Filename: src/main.bash
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

declare -A config=(
    [LOG_LEVEL]="INFO"  # Default log level
    [LOG_TO_CONSOLE]=false  # Default: don't log to console
    [BASE_DIR]="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
)

load_libraries() {
    source "${config[BASE_DIR]}/src/lib/_parser.bash"
    source "${config[BASE_DIR]}/src/lib/log_prod_output.bash"
}

main() {
    load_libraries
    parse_arguments "$@"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
