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

run_coverage_analysis() {
    local source_file="$1"
    local test_file="$2"

    # Create a temp directory for kcov
    local kcov_dir
    kcov_dir="$(mktemp -d)"

    # Run coverage analysis inside the test container
    run_in_docker "kcov --clean --include-path='${source_file}' \"${kcov_dir}\" bats '${test_file}' > /dev/null 2>&1"

    # Verify kcov output exists before proceeding
    if [[ -f "${kcov_dir}/bats/sonarqube.xml" ]]; then
        # Extract uncovered lines
        uncovered_lines=$(grep 'covered="false"' "${kcov_dir}/bats/sonarqube.xml" | sed -n 's/.*lineNumber="\([0-9]*\)".*/\1/p')
    else
        echo "⚠️  Warning: Coverage report missing. No coverage data available."
        uncovered_lines=""
    fi

    # Count total statements (approximated by the last line number in the source file)
    local total_statements
    total_statements=$(wc -l < "${source_file}")

    # Count the number of uncovered statements
    local missed_statements
    missed_statements=$(echo "$uncovered_lines" | wc -l)

    # Calculate coverage percentage (using floating point)
    local coverage
    if [[ "$total_statements" -gt 0 ]]; then
        coverage=$(awk "BEGIN {printf \"%.1f\", (100 - ($missed_statements * 100 / $total_statements))}")
    else
        coverage=100.0
    fi

    # Print tabular coverage output
    printf "\n%-30s %6s %6s %6s %s\n" "Name" "Stmts" "Miss" "Cover" "Missing"
    printf "%-30s %6d %6d %5.1f%% %s\n" "${source_file}" "${total_statements}" "${missed_statements}" "${coverage}" "${uncovered_lines:-None}"

    # Cleanup temporary files
    rm -rf "${kcov_dir}"
}

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

    # Run kcov inside Docker if --coverage is enabled
    if [[ "${CONFIG[COVERAGE]}" == "true" ]]; then
        echo "📊 Running coverage analysis..."
        local coverage_output
        coverage_output=$(run_in_docker "kcov_dir=\$(mktemp -d) && \
                       kcov --clean --include-path='${source_file}' \"\$kcov_dir\" bats '${test_file}' > /dev/null 2>&1 && \
                       cat \"\$kcov_dir/bats/sonarqube.xml\"")

        # Return the full coverage report (both covered and uncovered lines)
        echo "$coverage_output"
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
