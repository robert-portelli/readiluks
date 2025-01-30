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
# Last Updated:
#   See repository commit history (e.g., `git log`).

declare -A CONFIG=(
    [LOG_LEVEL]="INFO"  # Default log level
    [LOG_TO_CONSOLE]=false  # Default: don't log to console
    [BATS_FLAGS]=""
    [BASE_DIR]="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    [IMAGENAME]="robertportelli/test-readiluks:latest"
    [DOCKERIMAGE]="ubuntu-latest=${config[IMAGENAME]}"
    [TESTS]=""
)


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

test_common_setup() {
    gh act workflow_dispatch -j "test-bats-common-setup"
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

unit_test_parse_prod_args() {
    gh act workflow_dispatch -j "unit-test-parser"
    #gh act workflow_dispatch -j "test-parser" --input bats-flags="none"
}

integration_test_parse_prod_args() {
    #gh act workflow_dispatch -j "integration-test-parser" --input bats-flags="--verbose-run"
    #gh act workflow_dispatch -j "integration-test-parser" --env USE_TEST_PARSER=1
    gh act workflow_dispatch -j "integration-test-parser"
}

run_tests() {
    #test_common_setup
    #test_parse_prod_args_workflow
    #unit_test_parse_prod_args
    integration_test_parse_prod_args

}

main() {
    parse_test_arguments "$@"
    readonly -A CONFIG

    if [[ "$LOG_LEVEL" == "DEBUG" ]]; then
        log_config
    fi

    trap cleanup EXIT
    run_tests
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
