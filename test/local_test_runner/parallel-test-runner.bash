# ==============================================================================
# Filename: test/local_test_runner/parallel-test-runner.bash
# ------------------------------------------------------------------------------
# Description:
#   Parallel test runner for Readiluks test suite.
#   Executes multiple test functions in parallel via GNU parallel.
#
# Usage:
#   bash test/local_test_runner/parallel-test-runner.bash --test <test_function>
#   or:
#   bash test/local_test_runner/parallel-test-runner.bash --tests <list of test functions>
# ==============================================================================

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# -------------------------------------------
# Run Test Functions in Parallel (Level 1)
# -------------------------------------------
run_parallel_tests_1() {
    local test_functions=("$@")

    # Base command: source runner.bash and load libraries
    local sourcing_cmd
    sourcing_cmd="source \"$BASEDIR/test/local_test_runner/runner.bash\"; load_libraries; "

    # Build an array of commands for GNU parallel
    local cmds=()
    for test_fn in "${test_functions[@]}"; do
        cmds+=("bash -c \"$sourcing_cmd $test_fn\"")
    done

    echo "🚀 Running parallel tests: ${test_functions[*]}"

    # Run the commands in parallel
    parallel --jobs 0 ::: "${cmds[@]}"
}

# example parallel test set
test_parallel_tests_1() {
    run_parallel_tests_1 \
        test_device_fixture_register_test_device \
        test_device_fixture_setup_luks
}

main() {
    source "$BASEDIR/test/local_test_runner/runner.bash"
    load_libraries
    parse_arguments "$@"

    # Set cleanup trap immediately, ensuring cleanup happens even if something fails
    trap 'nested_container_cleanup' EXIT

    # Ensure CONFIG[TEST] is a valid function before executing it
    if declare -F "${CONFIG[TEST]}" >/dev/null; then
        "${CONFIG[TEST]}"
    else
        echo "Error: '${CONFIG[TEST]}' is not a valid test function"
        exit 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
