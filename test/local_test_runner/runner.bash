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
#   - Automates cleanup of test containers and loopback devices to prevent resource leaks.
#   - Introduces `test_dind_container` and `test_container` functions for
#     dynamic test execution inside nested and direct Docker containers.
#
# Functions:
#   - `test_dind_container`: Executes tests within a nested Docker container
#     inside the DinD environment, ensuring isolation.
#   - `test_container`: Runs a standard test container directly in the DinD environment.
#   - `manual_nested_container`: Allows manual execution of a nested container for debugging.
#   - `cleanup_test_device`: Ensures proper cleanup of the loopback device and image file.
#   - `nested_container_cleanup`: Handles the removal of any orphaned containers.
#
# Usage:
#   bash test/local_test_runner/runner.bash --test <test_function> [options]
#
# Example(s):
#   # Run a test script inside a nested container
#   bash test/local_test_runner/runner.bash --test test_dind_container
#
#   # Run a manual container for interactive debugging
#   bash test/local_test_runner/runner.bash --test manual_nested_container
#
# Requirements:
#   - Docker installed and running.
#   - The following Docker images must be available:
#       - `robertportelli/test-readiluks:latest`: Test container based on Arch Linux.
#       - `docker:dind`: Docker-in-Docker (DinD) container used for isolated testing.
#   - The following Dockerfiles are packaged with the repository:
#       - `docker/test/Dockerfile.inner`: Defines the test environment and is pushed to Docker Hub.
#       - `docker/test/Dockerfile.outer`: Defines the DinD environment used for nested containers.
#   - The outer DinD container must be running for isolated test execution.
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
    source "$BASEDIR/test/local_test_runner/lib/_manage_outer_docker.bash"
    source "$BASEDIR/test/local_test_runner/lib/_run-in-docker.bash"
    source "$BASEDIR/test/local_test_runner/lib/_run-test.bash"
    source "$BASEDIR/test/local_test_runner/lib/_nested-docker-cleanup.bash"
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

collect_coverage_data() {
    local test_functions=("$@")
    local all_lines_file
    local covered_lines_file
    local uncovered_lines_file
    all_lines_file="$(mktemp)"
    covered_lines_file="$(mktemp)"
    uncovered_lines_file="$(mktemp)"

    local source_file="UNKNOWN"

    # Step 1: Collect all possible lines that need coverage
    for test_function in "${test_functions[@]}"; do
        echo "🔍 Running $test_function..."
        local coverage_output
        coverage_output="$($test_function)"

        # Extract source file from SonarQube XML output
        if [[ "$source_file" == "UNKNOWN" ]]; then
            source_file=$(echo "$coverage_output" | grep -oP '(?<=<file path=")[^"]+' | head -n 1)
            source_file=$(basename "$source_file")  # Get only the filename
        fi

        # Extract all lines needing coverage
        echo "$coverage_output" | grep 'lineNumber="' | awk -F'"' '{print $2}' >> "$all_lines_file"
    done

    # Remove duplicates to get the full set of covered lines
    sort -u "$all_lines_file" -o "$all_lines_file"

    # Step 2: Collect covered lines from each test
    for test_function in "${test_functions[@]}"; do
        echo "📢 Processing results from: $test_function..."
        local coverage_output
        coverage_output="$($test_function)"
        echo "$coverage_output" | grep 'covered="true"' | awk -F'"' '{print $2}' >> "$covered_lines_file"
    done

    # Remove covered lines from the full list
    sort -u "$covered_lines_file" -o "$covered_lines_file"
    comm -23 "$all_lines_file" "$covered_lines_file" > "$uncovered_lines_file"

    # Step 3: Format and print the final coverage report
    format_coverage_report "$source_file" "$all_lines_file" "$covered_lines_file" "$uncovered_lines_file"

    # Cleanup
    rm -f "$all_lines_file" "$covered_lines_file" "$uncovered_lines_file"
}


format_missing_lines() {
    # shellcheck disable=SC2207
    local sorted_lines=($(echo "$1" | tr ',' '\n' | sort -n | uniq))
    local formatted=""
    local start=-1
    local prev=-1

    for line in "${sorted_lines[@]}"; do
        if [[ $start -eq -1 ]]; then
            start=$line
        elif [[ $((prev + 1)) -ne $line ]]; then
            if [[ $start -eq $prev ]]; then
                formatted+="${start},"
            else
                formatted+="${start}-${prev},"
            fi
            start=$line
        fi
        prev=$line
    done

    if [[ $start -eq $prev ]]; then
        formatted+="${start}"
    else
        formatted+="${start}-${prev}"
    fi

    echo "$formatted"
}

format_coverage_report() {
    local source_file="$1"
    local all_lines_file="$2"
    local covered_lines_file="$3"
    local uncovered_lines_file="$4"
    local report_tmp
    report_tmp="$(mktemp)"

    # Compute statistics
    local total_statements
    total_statements=$(wc -l < "$all_lines_file")

    local missed_statements
    missed_statements=$(wc -l < "$uncovered_lines_file")

    local coverage
    if [[ "$total_statements" -gt 0 ]]; then
        coverage=$((100 - (missed_statements * 100 / total_statements)))
    else
        coverage=100
    fi

    # Format missing lines
    local missing_lines
    # shellcheck disable=SC2002
    missing_lines=$(format_missing_lines "$(cat "$uncovered_lines_file" | tr '\n' ',' | sed 's/,$//')")

    # Store report
    printf "%-30s %6d %6d %5d%% %s\n" \
        "$source_file" "$total_statements" "$missed_statements" "$coverage" \
        "${missing_lines:-None}" >> "$report_tmp"

    # Print report
    echo -e "\n📊 Final Coverage Report:\n"
    printf "%-30s %6s %6s %6s %s\n" "Name" "Stmts" "Miss" "Cover" "Missing"
    printf "%-30s %6s %6s %6s %s\n" "------------------------------" "------" "------" "------" "----------------"
    cat "$report_tmp"
    printf "%-30s %6s %6s %6s %s\n" "------------------------------" "------" "------" "------" "----------------"

    rm -f "$report_tmp"
}

test_coverage_fixture() {
    collect_coverage_data \
        test_coverage_fixture_with_q1_coverage \
        test_coverage_fixture_with_q2_coverage \
        test_coverage_fixture_with_q3_coverage

}

test_device_fixture() {
    collect_coverage_data \
        test_device_fixture_setup_lvm \
        test_device_fixture_setup_luks \
        test_device_fixture_create_device \
        test_device_fixture_format_filesystem \
        test_device_fixture_teardown_device
}



test_dind_container() {
    # this is manual debugging test
    # Ensure DinD is running
    start_dind

    # Sanity check: Ensure the test-readiluks image exists inside DinD
    if ! docker exec "${CONFIG[DIND_CONTAINER]}" docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "${CONFIG[IMAGENAME]}"; then
        echo "❌ Image '${CONFIG[IMAGENAME]}' is missing inside DinD. Aborting."
        exit 1
    fi

    create_test_device

     # Run the test container inside DinD and correctly capture its ID
    CONTAINER_ID=$(docker exec "${CONFIG[DIND_CONTAINER]}" docker run -d \
        --privileged --user root \
        -v "${CONFIG[BASE_DIR]}:${CONFIG[BASE_DIR]}:ro" \
        -v /var/run/docker.sock:/var/run/docker.sock \
        --device="${CONFIG[TEST_DEVICE]}" \
        -e "TEST_DEVICE=${CONFIG[TEST_DEVICE]}" \
        -w "${CONFIG[BASE_DIR]}" \
        --user "$(id -u):$(id -g)" \
        "${CONFIG[IMAGENAME]}" bash -c "
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
    docker exec -it "${CONFIG[DIND_CONTAINER]}" docker logs -f "$CONTAINER_ID"

    # Ensure the test container is properly cleaned up after execution
    docker exec "${CONFIG[DIND_CONTAINER]}" docker stop "$CONTAINER_ID" > /dev/null 2>&1
    docker exec "${CONFIG[DIND_CONTAINER]}" docker rm -f "$CONTAINER_ID" > /dev/null 2>&1

    # Clean up the loopback device and image file
    trap EXIT INT TERM
        cleanup_test_device

}

test_container() {
    # this is manual debugging test
    # Ensure DinD is running
    start_dind

    # Sanity check: Ensure the test-readiluks image exists inside DinD
    if ! docker exec "${CONFIG[DIND_CONTAINER]}" docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "${CONFIG[IMAGENAME]}"; then
        echo "❌ Image '${CONFIG[IMAGENAME]}' is missing inside DinD. Aborting."
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
        "${CONFIG[IMAGENAME]}" bash

        # Ensure CONTAINER_ID is not empty
    if [[ -z "$CONTAINER_ID" ]]; then
        echo "❌ Failed to start test container inside DinD. Aborting."
        exit 1
    fi

    # Attach to the container logs
    docker exec -it "${CONFIG[DIND_CONTAINER]}" docker logs -f "$CONTAINER_ID"

    # Ensure the test container is properly cleaned up after execution
    docker exec "${CONFIG[DIND_CONTAINER]}" docker stop "$CONTAINER_ID" > /dev/null 2>&1
    docker exec "${CONFIG[DIND_CONTAINER]}" docker rm -f "$CONTAINER_ID" > /dev/null 2>&1

    # Clean up the loopback device and image file
    trap EXIT INT TERM
        cleanup_test_device
}

# bash test/local_test_runner/runner.bash --test manual_nested_container
manual_nested_container() {
    # this is manual debugging test
    docker exec -it "${CONFIG[DIND_CONTAINER]}" docker run --rm -it \
        --privileged --user root \
        -v "${CONFIG[BASE_DIR]}:${CONFIG[BASE_DIR]}:ro" \
        -w "/workspace" \
        "${CONFIG[IMAGENAME]}" bash
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

test_device_fixture_create_device() {
    local source_file="${CONFIG[BASE_DIR]}/test/local_test_runner/lib/_device_fixture.bash"
    local test_file="${CONFIG[BASE_DIR]}/test/local_test_runner/unit/test_device_fixture/test_create_device.bats"
    local workflow_event=""
    local workflow_job=""

    file_check "$source_file" "$test_file" || return 1

    run_test "$source_file" "$test_file" "$workflow_event" "$workflow_job"
}

create_device_coverage() {
    collect_coverage_data test_device_fixture_create_device
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
