parse_arguments() {
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --test) shift; CONFIG[TEST]="$1" ;;
            --coverage) CONFIG[COVERAGE]=true ;;
            --workflow) CONFIG[WORKFLOW]=true ;;
            --bats-flags) shift; CONFIG[BATS_FLAGS]="$1" ;;
            *) echo "Unknown option: $1"; exit 1 ;;
        esac
        shift
    done

    # Require --test flag
    if [[ -z "${CONFIG[TEST]}" ]]; then
        echo "Error: --test flag is required."
        exit 1
    fi
}
