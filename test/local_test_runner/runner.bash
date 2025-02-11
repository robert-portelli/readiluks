#!/usr/bin/env bash

# ==============================================================================
# Filename: test/local_test_runner/runner.bash
# ------------------------------------------------------------------------------
# Description:
#   Provides a unified interface for executing tests within a Dockerized
#   test environment. Supports running unit tests, integration tests,
#   coverage analysis, and workflow simulations using DinD (Docker-in-Docker).
#
# Purpose:
#   - Standardizes the execution of test cases across different environments.
#   - Provides a containerized execution context, ensuring reproducibility.
#   - Supports multiple test execution modes (unit, integration, workflow, coverage).
#   - Manages Docker-in-Docker (DinD) setup for isolated testing.
#   - Automates cleanup of test containers to prevent resource leaks.
#
# Usage:
#   bash test/local_test_runner/runner.bash --test <test_function> [options]
#
# Options:
#   --test <test_function>   Specify the test function to execute (required).
#   --coverage               Run code coverage analysis using kcov.
#   --workflow               Execute tests via GitHub Actions workflow.
#   --bats-flags "<flags>"   Pass additional flags to BATS test execution.
#
# Examples:
#   # Run unit tests for the parser
#   bash test/local_test_runner/runner.bash --test unit_test_parser
#
#   # Run unit tests and capture code coverage
#   bash test/local_test_runner/runner.bash --test unit_test_parser --coverage
#
#   # Run integration tests via GitHub Actions workflow
#   bash test/local_test_runner/runner.bash --test integration_test_parser --workflow
#
#   # Run unit tests with custom BATS flags
#   bash test/local_test_runner/runner.bash --test unit_test_parser --bats-flags "--timing"
#
# Requirements:
#   - Docker installed and running.
#   - The following Docker images must be available:
#       - `robertportelli/test-readiluks:latest`: Test container based on Arch Linux.
#       - `docker:dind`: Docker-in-Docker (DinD) container used for isolated testing.
#   - The following Dockerfiles are packaged with the repository:
#       - `docker/test/Dockerfile`: Defines the test environment and is pushed to Docker Hub.
#       - `docker/test/Dockerfile.dind`: Defines the DinD environment used for nested containers.
#   - The DinD container must be running for isolated test execution.
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


BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

load_libraries() {
    source "$BASEDIR/test/local_test_runner/lib/_runner-config.bash"
    source "$BASEDIR/test/local_test_runner/lib/_parser.bash"
    source "$BASEDIR/test/local_test_runner/lib/_docker-in-docker.bash"
    source "$BASEDIR/test/local_test_runner/lib/_run-in-docker.bash"
    source "$BASEDIR/test/local_test_runner/lib/_run-test.bash"
    source "$BASEDIR/test/local_test_runner/lib/_nested-docker-cleanup.bash"
}

file_check() {
    local source_file="$1"
    local test_file="$2"

    # Fail if either file is missing
    [[ -f "$source_file" && -f "$test_file" ]] || {
        echo "❌ ERROR: One or more required files are missing:" >&2
        [[ -f "$source_file" ]] || echo "   - ❌ Missing: $source_file" >&2
        [[ -f "$test_file" ]] || echo "   - ❌ Missing: $test_file" >&2
        return 1
    }
}

# bash test/local_test_runner/runner.bash --test manual_nested_container
manual_nested_container() {
    docker exec -it "${CONFIG[DIND_CONTAINER]}" docker run --rm -it \
        --privileged --user root \
        -v "${CONFIG[BASE_DIR]}:${CONFIG[BASE_DIR]}:ro" \
        -w "/workspace" \
        "${CONFIG[IMAGENAME]}" bash
}

test_device_fixture() {
    local source_file="${CONFIG[BASE_DIR]}/test/local_test_runner/lib/_device_fixture.bash"
    local test_file="${CONFIG[BASE_DIR]}/test/local_test_runner/unit/test_device_fixture.bats"
    local workflow_event=""
    local workflow_job=""

    file_check "$source_file" "$test_file" || return 1

    run_test "$source_file" "$test_file" "$workflow_event" "$workflow_job"
}

test_bats_common_setup() {
    local source_file="${CONFIG[BASE_DIR]}/test/lib/_common_setup.bash"
    local test_file="${CONFIG[BASE_DIR]}/test/unit/test_common_setup.bats"
    local workflow_event="workflow_dispatch"
    local workflow_job="test-bats-common-setup"

    file_check "$source_file" "$test_file" || return 1

    run_test "$source_file" "$test_file" "$workflow_event" "$workflow_job"
}

unit_test_parser() {
    local source_file="${CONFIG[BASE_DIR]}/src/lib/_parser.bash"
    local test_file="${CONFIG[BASE_DIR]}/test/unit/test_parser.bats"
    local workflow_event="workflow_dispatch"
    local workflow_job="unit-test-parser"

    file_check "$source_file" "$test_file" || return 1

    run_test "$source_file" "$test_file" "$workflow_event" "$workflow_job"
}

integration_test_parser() {
    local source_file="${CONFIG[BASE_DIR]}/src/main.bash"
    local test_file="${CONFIG[BASE_DIR]}/test/integration/test_parser.bats"
    local workflow_event="workflow_dispatch"
    local workflow_job="integration-test-parser"

    file_check "$source_file" "$test_file" || return 1

    run_test "$source_file" "$test_file" "$workflow_event" "$workflow_job"

}

main() {
    load_libraries
    parse_arguments "$@"

    # Set cleanup trap immediately, ensuring cleanup happens even if something fails
    trap cleanup EXIT

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
