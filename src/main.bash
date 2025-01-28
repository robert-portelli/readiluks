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

declare -A CONFIG=(
    [LOG_LEVEL]="INFO"  # Default log level
    [LOG_TO_CONSOLE]=false  # Default: don't log to console
    [BASE_DIR]="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
)

source "${CONFIG[BASE_DIR]}/src/lib/parse_prod_args.bash"
source "${CONFIG[BASE_DIR]}/src/lib/log_prod_output.bash"

main() {
    parse_arguments "$@"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
