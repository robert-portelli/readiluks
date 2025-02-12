# ==============================================================================
# Filename: test/local_test_runner/lib/_parser.bash
# ------------------------------------------------------------------------------
# Description:
#   Parses command-line arguments for the local test runner, setting the
#   appropriate test configuration options in the CONFIG array.
#
# Purpose:
#   - Standardizes CLI options for executing tests.
#   - Populates the CONFIG array with selected test execution parameters.
#   - Ensures required parameters are provided before proceeding.
#
# Options:
#   --test <test_function>   Specify the test function to execute (required).
#   --coverage               Enable code coverage analysis using kcov.
#   --workflow               Execute tests within a GitHub Actions workflow context.
#   --bats-flags "<flags>"   Pass additional flags to BATS test execution.
#
# Usage:
#   source "$BASEDIR/test/local_test_runner/lib/_parser.bash"
#   parse_arguments "$@"
#
# Example(s):
#   # Set test to "unit_test_parser"
#   parse_arguments --test unit_test_parser
#   echo "Executing test: ${CONFIG[TEST]}"  # Outputs: unit_test_parser
#
#   # Enable code coverage
#   parse_arguments --test unit_test_parser --coverage
#   echo "Coverage enabled: ${CONFIG[COVERAGE]}"  # Outputs: true
#
# Requirements:
#   - Must be sourced before calling `parse_arguments()`.
#   - Expects CONFIG array to be defined in `_runner-config.bash`.
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
