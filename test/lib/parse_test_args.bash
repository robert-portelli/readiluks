# Filename: test/lib/parse_test_args.sh

# Resolve BASE_DIR relative to this script
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Source the production parser
source "${BASE_DIR}/src/lib/parse_prod_args.bash"

parse_test_arguments() {
    local args=()

    # Filter out test-specific arguments before calling parse_arguments
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --debug-config) ;;  # Ignore it for now, handle it later
            *) args+=("$1") ;;   # Collect all other arguments
        esac
        shift
    done

    # Call the production parser with filtered arguments
    parse_arguments "${args[@]}"

    # Handle test-specific arguments after production parser runs
    for arg in "$@"; do
        case "$arg" in
            --debug-config)
                echo "LOG_LEVEL=${config[LOG_LEVEL]}"
                echo "LOG_TO_CONSOLE=${config[LOG_TO_CONSOLE]}"
                exit 0
                ;;
        esac
    done
}
