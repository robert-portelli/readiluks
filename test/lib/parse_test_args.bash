# Filename: test/lib/parse_test_args.bash
parse_arguments() {
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --log-level)
                shift
                if [[ -n "$1" ]]; then
                    config[LOG_LEVEL]="$1"
                    shift
                else
                    echo "ERROR: Invalid log level" >&2
                    return 1
                fi
                ;;
            --log-to-console)
                config[LOG_TO_CONSOLE]=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [--log-level {DEBUG|INFO|WARNING|ERROR}] [--log-to-console]"
                return 0
                ;;
            --debug-config)
                echo "LOG_LEVEL=${config[LOG_LEVEL]}"
                echo "LOG_TO_CONSOLE=${config[LOG_TO_CONSOLE]}"
                exit 0
                ;;
            *)
                echo "ERROR: Unknown option: $1" >&2
                return 1
                ;;
        esac
    done
}
