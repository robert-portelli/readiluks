# ==============================================================================
# Filename: test/local_test_runner/lib/_run-test.bash
# ------------------------------------------------------------------------------
# Description:
#   Executes requested tests within a nested test container inside DinD.
#   Supports unit tests, integration tests, coverage analysis, and workflow tests.
#
# Purpose:
#   - Determines the requested test type (unit, integration, workflow).
#   - Executes the appropriate test command inside a nested container.
#   - Runs BATS tests for unit/integration tests.
#   - Supports coverage analysis with kcov.
#   - Executes workflow tests using `act` to simulate GitHub Actions.
#
# Options:
#   This script does not accept command-line options. It is sourced by the test
#   runner and its functions.
#
# Usage:
#   source "$BASEDIR/test/local_test_runner/lib/_run-test.bash"
#   run_test <source_file> <test_file> <workflow_event> <workflow_job>
#
# Example(s):
#   # Run a unit test
#   run_test "src/lib/_parser.bash" "test/unit/test_parser.bats" "" ""
#
#   # Run an integration test
#   run_test "src/main.bash" "test/integration/test_parser.bats" "" ""
#
#   # Run a coverage test
#   CONFIG[COVERAGE]=true
#   run_test "src/lib/_parser.bash" "test/unit/test_parser.bats" "" ""
#
#   # Run a workflow test
#   CONFIG[WORKFLOW]=true
#   run_test "src/lib/_parser.bash" "test/unit/test_parser.bats" "workflow_dispatch" "unit-test-parser"
#
# Requirements:
#   - Must be sourced before calling `run_test()`.
#   - Requires `_run-in-docker.bash` for spawning nested test containers.
#   - Requires `_runner-config.bash` for test environment settings.
#   - Assumes BATS is installed for running shell script tests.
#   - Assumes kcov is installed for code coverage analysis.
#   - Assumes `act` is available for workflow tests.
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
        run_in_docker "bats '${CONFIG[BATS_FLAGS]}' '${test_file}'"
    fi

    # Run kcov if --coverage was passed
    if [[ "${CONFIG[COVERAGE]}" == "true" ]]; then
        echo "📊 Running coverage analysis..."
        run_in_docker "kcov_dir=\$(mktemp -d) && \
                       echo '📂 Temporary kcov directory: \$kcov_dir' && \
                       kcov --clean --include-path='${source_file}' \"\$kcov_dir\" bats '${test_file}' && \
                       echo '📝 Uncovered lines:' && \
                       grep 'covered=\"false\"' \"\$kcov_dir/bats/sonarqube.xml\" || echo '✅ All lines covered.' && \
                       rm -rf \"\$kcov_dir\""
    fi

    # Run workflow tests if --workflow was passed
    if [[ "${CONFIG[WORKFLOW]}" == "true" ]]; then
        echo "🚀 Running workflow tests for job: ${workflow_job}"
        run_in_docker "act \
                        '${workflow_event}' \
                        -P ${CONFIG[DOCKERIMAGE]} \
                        --pull=false \
                        -j '${workflow_job}' \
                        --input bats-flags=${CONFIG[BATS_FLAGS]}"
    fi

    echo "✅ $test_name completed."
}
