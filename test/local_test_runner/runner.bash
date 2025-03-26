#!/usr/bin/env bash

# ==============================================================================
# Filename: test/local_test_runner/runner.bash
# ------------------------------------------------------------------------------
# Description:
#   Provides a unified interface for executing tests within a Dockerized
#   test environment. Supports unit tests, integration tests, coverage analysis,
#   and GitHub Actions workflow simulations, all inside a Docker-in-Docker (DinD) setup.
#
# Purpose:
#   - Standardizes test execution for Readiluks with clear, consistent workflows.
#   - Provides containerized and reproducible test runs by leveraging Docker-in-Docker.
#   - Runs unit, integration, workflow tests, and collects coverage reports.
#   - Delegates coverage collection and reporting to the encapsulated _coverage.bash module.
#   - Automates cleanup of containers, loop devices, and other test resources.
#   - Offers interactive debugging through manual container execution.
#
# Functions:
#   - load_libraries: Loads all test runner and utility libraries, including _coverage.bash.
#   - test_coverage_fixture_with_q[1-4]_coverage: Runs coverage tests for specific test groups.
#   - test_coverage_fixture: Aggregates coverage for the _coverage_fixture module.
#   - test_device_fixture_[register|setup_luks|setup_lvm|format_filesystem|teardown_device]:
#       Runs unit tests for device fixture lifecycle.
#   - test_device_fixture: Aggregates coverage for device fixture tests.
#   - test_bats_common_setup: Runs unit tests for shared setup helpers (_common_setup.bash).
#   - unit_test_parser / integration_test_parser: Tests argument parsing and integration flow.
#   - test_dind_container / test_container: Launches test containers (DinD or direct) for debugging.
#   - manual_nested_container: Runs an interactive nested container inside DinD.
#   - file_check: Validates presence of required source and test files before execution.
#   - main: Parses arguments, loads config, and dispatches to the specified test function.
#
# Usage:
#   bash test/local_test_runner/runner.bash --test <test_function> [options]
#
# Example(s):
#   # Run a specific unit test
#   bash test/local_test_runner/runner.bash --test test_device_fixture_register_test_device
#
#   # Run all coverage tests for device fixtures
#   bash test/local_test_runner/runner.bash --test test_device_fixture --coverage
#
#   # Run an integration test with workflow simulation
#   bash test/local_test_runner/runner.bash --test integration_test_parser --workflow
#
#   # Start a manual nested container for debugging inside DinD
#   bash test/local_test_runner/runner.bash --test manual_nested_container
#
# Requirements:
#   - Docker installed and running on the host.
#   - Docker-in-Docker (DinD) image available:
#       - `docker:dind` or custom-built from `docker/test/Dockerfile.outer`
#   - Test container image available:
#       - `robertportelli/test-readiluks:latest` or built from `docker/test/Dockerfile.inner-harness-harness`
#   - Inner test container must include BATS, kcov, and act.
#   - Requires `kcov` for code coverage and `act` for GitHub Actions workflow simulations.
#
# CI/CD Integration:
#   - GitHub Actions workflows simulate local runs via `act`.
#   - Pre-merge testing and coverage checks are automated through CI pipelines.
#   - Super-Linter runs automated linting and style checks.
#
# Version:
#   See repository tags or release notes for the current version.
#
# License:
#   MIT License. See LICENSE.md and repository commit history (`git log`).
#
# Author:
#   Robert Portelli
#   https://github.com/robert-portelli/readiluks
# ==============================================================================

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

load_libraries() {
    source "$BASEDIR/test/local_test_runner/lib/_coverage.bash"
    source "$BASEDIR/test/local_test_runner/lib/_runner-config.bash"
    source "$BASEDIR/test/local_test_runner/lib/_parser.bash"
    source "$BASEDIR/test/local_test_runner/lib/_manage_outer_docker.bash"
    source "$BASEDIR/test/local_test_runner/lib/_run-inner-harness.bash"
    source "$BASEDIR/test/local_test_runner/lib/_run-test.bash"
}

test_systemd_container() {
    # point the outer container at the systemd container instead of test container
    CONFIG[HARNESS_IMAGE]="robertportelli/readiluks-systemd-inner:latest"
    # this is manual debugging test
    # Ensure DinD is running
    start_outer_container

    # Sanity check: Ensure the test-readiluks image exists inside DinD
    if ! docker exec "${CONFIG[OUTER_CONTAINER]}" docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "${CONFIG[HARNESS_IMAGE]}"; then
        echo "❌ Image '${CONFIG[HARNESS_IMAGE]}' is missing inside DinD. Aborting."
        exit 1
    fi

    docker exec "${CONFIG[OUTER_CONTAINER]}" docker run -d \
      --name inner-sysd \
      --privileged \
      --tmpfs /tmp --tmpfs /run --tmpfs /run/lock \
      -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
      --cgroupns=host \
      robertportelli/readiluks-systemd-inner:latest

}

test_coverage_fixture_with_q1_coverage() {
    local source_file="${CONFIG[BASE_DIR]}/test/coverage/lib/_coverage_fixture.bash"
    local test_file="${CONFIG[BASE_DIR]}/test/coverage/unit/q1_coverage.bats"
    local workflow_event=""
    local workflow_job=""

    file_check "$source_file" "$test_file" || return 1

    run_test "$source_file" "$test_file" "$workflow_event" "$workflow_job"
}

test_coverage_fixture_with_q2_coverage() {
    local source_file="${CONFIG[BASE_DIR]}/test/coverage/lib/_coverage_fixture.bash"
    local test_file="${CONFIG[BASE_DIR]}/test/coverage/unit/q2_coverage.bats"
    local workflow_event=""
    local workflow_job=""

    file_check "$source_file" "$test_file" || return 1

    run_test "$source_file" "$test_file" "$workflow_event" "$workflow_job"
}

test_coverage_fixture_with_q3_coverage() {
    local source_file="${CONFIG[BASE_DIR]}/test/coverage/lib/_coverage_fixture.bash"
    local test_file="${CONFIG[BASE_DIR]}/test/coverage/unit/q3_coverage.bats"
    local workflow_event=""
    local workflow_job=""

    file_check "$source_file" "$test_file" || return 1

    run_test "$source_file" "$test_file" "$workflow_event" "$workflow_job"
}

test_coverage_fixture_with_q4_coverage() {
    local source_file="${CONFIG[BASE_DIR]}/test/coverage/lib/_coverage_fixture.bash"
    local test_file="${CONFIG[BASE_DIR]}/test/coverage/unit/q4_coverage.bats"
    local workflow_event=""
    local workflow_job=""

    file_check "$source_file" "$test_file" || return 1

    run_test "$source_file" "$test_file" "$workflow_event" "$workflow_job"
}


test_coverage_fixture() {
    collect_coverage_data \
        test_coverage_fixture_with_q1_coverage \
        test_coverage_fixture_with_q2_coverage \
        test_coverage_fixture_with_q3_coverage

}

test_device_fixture() {
    collect_coverage_data \
        test_device_fixture_register_test_device \
        test_device_fixture_setup_luks \
        test_device_fixture_setup_lvm \
        test_device_fixture_format_filesystem \
        test_device_fixture_teardown_device

}



test_dind_container() {
    # this is manual debugging test
    # Ensure DinD is running
    start_outer_container

    # Sanity check: Ensure the test-readiluks image exists inside DinD
    if ! docker exec "${CONFIG[OUTER_CONTAINER]}" docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "${CONFIG[HARNESS_IMAGE]}"; then
        echo "❌ Image '${CONFIG[HARNESS_IMAGE]}' is missing inside DinD. Aborting."
        exit 1
    fi

    create_test_device

     # Run the test container inside DinD and correctly capture its ID
    CONTAINER_ID=$(docker exec "${CONFIG[OUTER_CONTAINER]}" docker run -d \
        --privileged --user root \
        -v "${CONFIG[BASE_DIR]}:${CONFIG[BASE_DIR]}:ro" \
        -v /var/run/docker.sock:/var/run/docker.sock \
        --device="${CONFIG[TEST_DEVICE]}" \
        -e "TEST_DEVICE=${CONFIG[TEST_DEVICE]}" \
        -w "${CONFIG[BASE_DIR]}" \
        --user "$(id -u):$(id -g)" \
        "${CONFIG[HARNESS_IMAGE]}" bash -c "
            echo 'TEST_DEVICE in container: \$TEST_DEVICE';
            lsblk;
            ls -l /dev/loop*;
            stat \$TEST_DEVICE;
            udevadm trigger;
            udevadm settle;
            $cmd
        ")

        # Ensure CONTAINER_ID is not empty
    if [[ -z "$CONTAINER_ID" ]]; then
        echo "❌ Failed to start test container inside DinD. Aborting."
        exit 1
    fi

    # Attach to the container logs
    docker exec -it "${CONFIG[OUTER_CONTAINER]}" docker logs -f "$CONTAINER_ID"

    # Ensure the test container is properly cleaned up after execution
    docker exec "${CONFIG[OUTER_CONTAINER]}" docker stop "$CONTAINER_ID" > /dev/null 2>&1
    docker exec "${CONFIG[OUTER_CONTAINER]}" docker rm -f "$CONTAINER_ID" > /dev/null 2>&1

    # Clean up the loopback device and image file
    trap EXIT INT TERM
        cleanup_test_device

}

test_container() {
    # this is manual debugging test
    # Ensure DinD is running
    start_outer_container

    # Sanity check: Ensure the test-readiluks image exists inside DinD
    if ! docker exec "${CONFIG[OUTER_CONTAINER]}" docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "${CONFIG[HARNESS_IMAGE]}"; then
        echo "❌ Image '${CONFIG[HARNESS_IMAGE]}' is missing inside DinD. Aborting."
        exit 1
    fi

    create_test_device

     # Run the test container inside DinD and correctly capture its ID
    docker run -it \
        --privileged --user root \
        -v "${CONFIG[BASE_DIR]}:${CONFIG[BASE_DIR]}:ro" \
        -v /var/run/docker.sock:/var/run/docker.sock \
        --device="${CONFIG[TEST_DEVICE]}" \
        -e "TEST_DEVICE=${CONFIG[TEST_DEVICE]}" \
        -w "${CONFIG[BASE_DIR]}" \
        --user "$(id -u):$(id -g)" \
        "${CONFIG[HARNESS_IMAGE]}" bash

        # Ensure CONTAINER_ID is not empty
    if [[ -z "$CONTAINER_ID" ]]; then
        echo "❌ Failed to start test container inside DinD. Aborting."
        exit 1
    fi

    # Attach to the container logs
    docker exec -it "${CONFIG[OUTER_CONTAINER]}" docker logs -f "$CONTAINER_ID"

    # Ensure the test container is properly cleaned up after execution
    docker exec "${CONFIG[OUTER_CONTAINER]}" docker stop "$CONTAINER_ID" > /dev/null 2>&1
    docker exec "${CONFIG[OUTER_CONTAINER]}" docker rm -f "$CONTAINER_ID" > /dev/null 2>&1

    # Clean up the loopback device and image file
    trap EXIT INT TERM
        cleanup_test_device
}

# bash test/local_test_runner/runner.bash --test manual_nested_container
manual_nested_container() {
    # this is manual debugging test
    docker exec -it "${CONFIG[OUTER_CONTAINER]}" docker run --rm -it \
        --privileged --user root \
        -v "${CONFIG[BASE_DIR]}:${CONFIG[BASE_DIR]}:ro" \
        -w "/workspace" \
        "${CONFIG[HARNESS_IMAGE]}" bash
}

test_device_fixture_teardown_device() {
    local source_file="${CONFIG[BASE_DIR]}/test/local_test_runner/lib/_device_fixture.bash"
    local test_file="${CONFIG[BASE_DIR]}/test/local_test_runner/unit/test_device_fixture/test_teardown_device.bats"
    local workflow_event=""
    local workflow_job=""

    file_check "$source_file" "$test_file" || return 1

    run_test "$source_file" "$test_file" "$workflow_event" "$workflow_job"
}


test_device_fixture_format_filesystem() {
    local source_file="${CONFIG[BASE_DIR]}/test/local_test_runner/lib/_device_fixture.bash"
    local test_file="${CONFIG[BASE_DIR]}/test/local_test_runner/unit/test_device_fixture/test_format_filesystem.bats"
    local workflow_event=""
    local workflow_job=""

    file_check "$source_file" "$test_file" || return 1

    run_test "$source_file" "$test_file" "$workflow_event" "$workflow_job"
}

test_device_fixture_setup_lvm() {
    local source_file="${CONFIG[BASE_DIR]}/test/local_test_runner/lib/_device_fixture.bash"
    local test_file="${CONFIG[BASE_DIR]}/test/local_test_runner/unit/test_device_fixture/test_setup_lvm.bats"
    local workflow_event=""
    local workflow_job=""

    file_check "$source_file" "$test_file" || return 1

    run_test "$source_file" "$test_file" "$workflow_event" "$workflow_job"
}

test_device_fixture_setup_luks() {
    local source_file="${CONFIG[BASE_DIR]}/test/local_test_runner/lib/_device_fixture.bash"
    local test_file="${CONFIG[BASE_DIR]}/test/local_test_runner/unit/test_device_fixture/test_setup_luks.bats"
    local workflow_event=""
    local workflow_job=""

    file_check "$source_file" "$test_file" || return 1

    run_test "$source_file" "$test_file" "$workflow_event" "$workflow_job"
}

test_device_fixture_register_test_device() {
    local source_file="${CONFIG[BASE_DIR]}/test/local_test_runner/lib/_device_fixture.bash"
    local test_file="${CONFIG[BASE_DIR]}/test/local_test_runner/unit/test_device_fixture/test_register_test_device.bats"
    local workflow_event=""
    local workflow_job=""

    file_check "$source_file" "$test_file" || return 1

    run_test "$source_file" "$test_file" "$workflow_event" "$workflow_job"
}

register_test_device_coverage() {
    collect_coverage_data test_device_fixture_register_test_device
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

main() {
    load_libraries
    parse_arguments "$@"

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
