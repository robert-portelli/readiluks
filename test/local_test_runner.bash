#!/usr/bin/env bash

# Filename:
# Description:
# Purpose:
# Usage:
# Options:
# Examples:

# Requirements:
# Author:
#   Robert Portelli
#   Repository: https://github.com/robert-portelli/readiluks
# Version:
#   See repository tags or release notes.
# License:
#   See repository license file (e.g., LICENSE.md).
#   See repository commit history (e.g., `git log`).

declare -A CONFIG=(
    [BASE_DIR]="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    [IMAGENAME]="robertportelli/test-readiluks:latest"
    [DOCKERIMAGE]="ubuntu-latest=${config[IMAGENAME]}"
    [TEST]=""
    [COVERAGE]=false
    [WORKFLOW]=false
)

parse_arguments() {
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --test) shift; CONFIG[TEST]="$1" ;;
            --coverage) CONFIG[COVERAGE]=true ;;
            --workflow) CONFIG[WORKFLOW]=true ;;
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

run_in_docker() {
    local cmd="$1"
    docker run --rm \
        -v "$(pwd):${CONFIG[BASE_DIR]}" \
        -w "${CONFIG[BASE_DIR]}" \
        "${CONFIG[IMAGENAME]}" bash -c "$cmd"
}

test_bats_common_setup() {
    local filename
    filename="test_common_setup.bats"
    run_in_docker "bats ${CONFIG[BASE_DIR]}/test/${filename}"
}

test_common_setup() {
    run_in_docker "act workflow_dispatch -j 'test-bats-common-setup'"
}

test_parse_prod_args_workflow() {
    # emulate PR trigger
    gh act pull_request -j  "test-parser"
    # emulate manual trigger with default bats flags provided by workflow:
    gh act workflow_dispatch -j "test-parser"
    # emulate manual trigger with overriding bats flags:
    gh act workflow_dispatch -j "test-parser" --input bats-flags="--timing"
    # emulate manual trigger without bats flags:
    gh act workflow_dispatch -j "test-parser" --input bats-flags=""
}

unit_test_parser() {
    #gh act workflow_dispatch -j "unit-test-parser"
    #gh act workflow_dispatch -j "test-parser" --input bats-flags="none"
    gh act workflow_dispatch -j "unit-test-parser" --input bats-flags="--verbose-run"
}

integration_test_parser() {
    gh act workflow_dispatch -j "integration-test-parser" --input bats-flags="--verbose-run"
    #gh act workflow_dispatch -j "integration-test-parser" --env USE_TEST_PARSER=1
    #gh act workflow_dispatch -j "integration-test-parser"
}

run_tests() {
    #test_common_setup
    #test_parse_prod_args_workflow
    unit_test_parser
    integration_test_parser

}

cleanup() {
    local containers
    containers=$(docker ps -a -q --filter ancestor="${CONFIG[IMAGENAME]}")

    if [[ -n "$containers" ]]; then
        echo "Found containers for '${CONFIG[IMAGENAME]}': $containers"
        echo "Removing containers..."
        # shellcheck disable=SC2086
        docker rm -f $containers || echo "Failed to remove some containers" >&2
    else
        echo "No containers found for image '${CONFIG[IMAGENAME]}'."
    fi
}

main() {
    parse_arguments "$@"

    # Ensure CONFIG[TEST] is a valid function before executing it
    if declare -F "${CONFIG[TEST]}" >/dev/null; then
        trap cleanup EXIT
        "${CONFIG[TEST]}"
    else
        echo "Error: '${CONFIG[TEST]}' is not a valid test function"
        exit 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
