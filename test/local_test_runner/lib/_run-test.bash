# ==============================================================================
# Filename: test/local_test_runner/lib/_run-test.bash
# ------------------------------------------------------------------------------
# Description:
#   Executes tests within a nested test container running inside the outer
#   Docker-in-Docker (DinD) environment. Supports unit tests, integration tests,
#   coverage analysis using kcov, and workflow tests simulated via `act`.
#
# Purpose:
#   - Runs BATS tests (unit or integration) inside the nested test container.
#   - Performs code coverage analysis using `kcov`, capturing results in SonarQube XML format.
#   - Executes workflow tests using `act` to simulate GitHub Actions workflows inside DinD.
#   - Supports dynamic switching between test types based on the `CONFIG` flags:
#       * `CONFIG[COVERAGE]` - enables coverage testing.
#       * `CONFIG[WORKFLOW]` - enables workflow testing.
#   - Streams output from tests in real time for easy feedback.
#
# Functions:
#   - run_test:
#       Executes BATS unit/integration tests, coverage analysis with `kcov`,
#       or workflow simulations with `act` depending on the provided configuration.
#
# Usage:
#   source "$BASEDIR/test/local_test_runner/lib/_run-test.bash"
#   run_test <source_file> <test_file> <workflow_event> <workflow_job>
#
# Example(s):
#   # Run a unit test with BATS (default behavior)
#   run_test "src/lib/_parser.bash" "test/unit/test_parser.bats" "" ""
#
#   # Run an integration test with BATS
#   run_test "src/main.bash" "test/integration/test_parser.bats" "" ""
#
#   # Run a coverage test using kcov
#   CONFIG[COVERAGE]=true
#   run_test "src/lib/_parser.bash" "test/unit/test_parser.bats" "" ""
#
#   # Run a workflow test using act
#   CONFIG[WORKFLOW]=true
#   run_test "src/lib/_parser.bash" "test/unit/test_parser.bats" "workflow_dispatch" "unit-test-parser"
#
# Requirements:
#   - Must be sourced before calling `run_test()`.
#   - Requires `_run-inner-harness.bash` to manage container execution in DinD.
#   - Requires `_runner-config.bash` to load the global `CONFIG` settings.
#   - Requires BATS installed in the test container for shell script testing.
#   - Requires kcov installed in the test container for coverage reporting.
#   - Requires `act` installed in the test container for workflow simulations.
#   - Assumes Docker and DinD are configured and running.
#
# Author:
#   Robert Portelli
#   Repository: https://github.com/robert-portelli/readiluks
#
# Version:
#   See repository tags or release notes.
#
# License:
#   See repository license file (e.g., LICENSE.md).
#   See repository commit history (e.g., `git log`).
# ==============================================================================

run_test() {
    local test_name="${FUNCNAME[1]}"
    local source_file="$1"
    local test_file="$2"
    local workflow_event="$3"
    local workflow_job="$4"

    echo "📢 Running test: $test_name"

    # Ensure BASE_DIR is set
    if [[ -z "${CONFIG[BASE_DIR]}" ]]; then
        echo "❌ ERROR: CONFIG[BASE_DIR] is empty. Aborting."
        exit 1
    fi

    # Run unit tests if neither --coverage nor --workflow were passed
    if [[ "${CONFIG[COVERAGE]}" == "false" && "${CONFIG[WORKFLOW]}" == "false" ]]; then
        echo "🧪 Running BATS tests: ${test_file}"
        run_systemd_container "bats '${CONFIG[BATS_FLAGS]}' '${test_file}'"
    fi

    # Run kcov inside Docker if --coverage is enabled
    if [[ "${CONFIG[COVERAGE]}" == "true" ]]; then
        echo "📊 Running coverage analysis..."
        local coverage_output
        coverage_output=$(run_systemd_container "kcov_dir=\$(mktemp -d) && \
                       kcov --clean --include-path='${source_file}' \"\$kcov_dir\" bats '${test_file}' > /dev/null 2>&1 && \
                       cat \"\$kcov_dir/bats/sonarqube.xml\"")

        # Return the full coverage report (both covered and uncovered lines)
        if [[ -n "$COVERAGE_FILE" ]]; then
            echo "$coverage_output" > "$COVERAGE_FILE"
        else
            echo "$coverage_output"
        fi
    fi

    # Run workflow tests if --workflow was passed
    if [[ "${CONFIG[WORKFLOW]}" == "true" ]]; then
        echo "🚀 Running workflow tests for job: ${workflow_job}"
        run_systemd_container "act \
                        '${workflow_event}' \
                        -P ${CONFIG[ACT_MAPPING]} \
                        --pull=false \
                        -j '${workflow_job}' \
                        --input bats-flags=${CONFIG[BATS_FLAGS]}"
    fi

    echo "✅ $test_name completed."
}
