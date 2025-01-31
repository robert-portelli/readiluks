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

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

load_config() {
    source "${BASE_DIR}/src/lib/_main_config.bash"
}

load_libraries() {
    source "${BASE_DIR}/src/lib/_parser.bash"
    source "${BASE_DIR}/src/lib/_logger.bash"
}

main() {
    load_config
    load_libraries
    parse_arguments "$@"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
