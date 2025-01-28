# Filename: test/lib/parse_test_args.sh

# Resolve BASE_DIR relative to this script
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Source the production parser
source "${BASE_DIR}/src/lib/parse_prod_args.bash"

parse_test_arguments() {
    # Process test-specific arguments first
    local remaining_args=()

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --bats-flags)
                shift
                if [[ -n "$1" ]]; then
                    # shellcheck disable=SC2034
                    CONFIG[BATS_FLAGS]="$1"
                    shift
                else
                    echo "Error: No flags provided after --bats-flags."
                    exit 1
                fi
                ;;
            --help|-h)
                # Extend help message to include test-specific flags
                echo "Usage: $0 [--log-level {DEBUG|INFO|WARNING|ERROR}] [--log-to-console] [--bats-flags '<flags>']"
                exit 0
                ;;
            *)
                # Collect unknown arguments to pass to the production parser
                remaining_args+=("$1")
                shift
                ;;
        esac
    done

    # Pass the remaining arguments to the production parser
    if [[ ${#remaining_args[@]} -gt 0 ]]; then
        parse_prod_arguments "${remaining_args[@]}"
    fi
}
