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
#   - Runs unit, integration, and workflow tests with configurable coverage reporting.
#   - Automates cleanup of containers, loop devices, and other test resources.
#   - Offers interactive debugging through manual container execution.
#
# Functions:
#   - load_libraries: Loads all test runner and utility libraries.
#   - test_coverage_fixture_with_q[1-4]_coverage: Runs coverage tests for specific test groups.
#   - test_device_fixture_[register|setup_luks|setup_lvm|format_filesystem|teardown_device]:
#       Runs unit tests for the device fixture lifecycle.
#   - collect_coverage_data: Executes multiple test functions and generates coverage reports.
#   - format_coverage_report: Outputs a pytest-cov style report from collected coverage data.
#   - test_bats_common_setup: Runs unit tests for shared setup helpers.
#   - unit_test_parser / integration_test_parser: Tests argument parsing, unit and integration.
#   - test_dind_container / test_container: Launches test containers interactively or for debugging.
#   - manual_nested_container: Runs a manual nested container for debugging inside DinD.
#   - file_check: Validates the presence of source and test files before execution.
#   - main: Parses arguments, loads config, and dispatches to the correct test function.
#
# Usage:
#   bash test/local_test_runner/runner.bash --test <test_function> [options]
#
# Example(s):
#   # Run a specific unit test
#   bash test/local_test_runner/runner.bash --test test_device_fixture_register_test_device
#
#   # Run integration tests with coverage
#   bash test/local_test_runner/runner.bash --test integration_test_parser --coverage
#
#   # Start a manual debugging container inside DinD
#   bash test/local_test_runner/runner.bash --test manual_nested_container
#
# Requirements:
#   - Docker installed and running on the host.
#   - Docker-in-Docker (DinD) image available:
#       - `docker:dind` or custom-built from `docker/test/Dockerfile.outer`
#   - Test container image available:
#       - `robertportelli/test-readiluks:latest` or built from `docker/test/Dockerfile.inner`
#   - Inner test container must include BATS, kcov, and act.
#   - Requires `kcov` for code coverage and `act` for workflow simulations.
#
# CI/CD Integration:
#   - GitHub Actions workflow simulations supported via `act`.
#   - Pre-merge workflow validation and coverage enforced via CI.
#   - Super-Linter configured for static analysis and style enforcement.
#
# Author:
#   Robert Portelli
#   Repository: https://github.com/robert-portelli/readiluks
#
# Version:
#   See repository tags or release notes.
#
# License:
#   MIT License. See LICENSE.md and repository commit history (`git log`).
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

print_timing_line() {
    local label="$1"  # e.g. "✅ test_device_fixture_setup_luks completed in:"
    local time="$2"   # e.g. "50.673"

    local total_width=88  # Target column where 's' ends (tweak this number as needed)
    local label_length=${#label}
    local time_length=${#time}

    local spaces=$((total_width - label_length - time_length - 1))  # 1 for 's'

    # Safety check to prevent negative spacing
    [[ $spaces -lt 1 ]] && spaces=1

    # Build the padding
    local padding
    padding=$(printf '%*s' "$spaces" "")

    # Print the result
    printf "%s%s%s\n" "$label" "$padding" "$time"s
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

    # Start the total timer
    local start_total
    start_total=$(date +%s%3N)

    #echo -e "\nCoverage Report:\n"

    # Step 1: Collect coverage output and data per test (single run!)
    for test_function in "${test_functions[@]}"; do
        echo "🔍 Running $test_function..."

        local start_time
        start_time=$(date +%s%3N)

        local coverage_output
        coverage_output="$($test_function)"

        local end_time
        end_time=$(date +%s%3N)
        local elapsed_ms
        elapsed_ms=$((end_time - start_time))
        local elapsed_sec
        elapsed_sec="$((elapsed_ms / 1000)).$(printf "%03d" $((elapsed_ms % 1000)))"

        print_timing_line "✅ $test_function completed in:" "$elapsed_sec"

        # Extract source file if not already done
        if [[ "$source_file" == "UNKNOWN" ]]; then
            source_file=$(echo "$coverage_output" | grep -oP '(?<=<file path=")[^"]+' | head -n 1)
            source_file=$(basename "$source_file")
        fi

        # Collect all lines needing coverage
        echo "$coverage_output" | grep 'lineNumber="' | awk -F'"' '{print $2}' >> "$all_lines_file"

        # Collect covered lines
        echo "$coverage_output" | grep 'covered="true"' | awk -F'"' '{print $2}' >> "$covered_lines_file"
    done

    # Remove duplicates
    sort -u "$all_lines_file" -o "$all_lines_file"
    sort -u "$covered_lines_file" -o "$covered_lines_file"

    # Compute uncovered lines
    comm -23 "$all_lines_file" "$covered_lines_file" > "$uncovered_lines_file"

    # End the total timer
    local end_total
    end_total=$(date +%s%3N)
    local total_elapsed_ms
    total_elapsed_ms=$((end_total - start_total))
    local total_elapsed_sec
     total_elapsed_sec="$((total_elapsed_ms / 1000)).$(printf "%03d" $((total_elapsed_ms % 1000)))"

    echo ""
    print_timing_line "⏱️  Total Runtime:" "$total_elapsed_sec"

    format_coverage_report "$source_file" "$all_lines_file" "$covered_lines_file" "$uncovered_lines_file"

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

calculate_coverage() {
    local missed="$1"
    local total="$2"
    awk -v missed="$missed" -v total="$total" 'BEGIN {
        if (total > 0)
            printf "%.2f", 100 - (missed * 100 / total);
        else
            printf "100.00";
    }'
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
        coverage=$(calculate_coverage "$missed_statements" "$total_statements")
    else
        coverage="100"
    fi

    # Format missing lines
    local missing_lines
    missing_lines=$(format_missing_lines "$(tr '\n' ',' < "$uncovered_lines_file" | sed 's/,$//')")

    # Store report
    printf "%-30s %6d %6d %6.2f%% %s\n" \
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
        test_device_fixture_register_test_device \
        test_device_fixture_setup_luks \
        test_device_fixture_setup_lvm \
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
