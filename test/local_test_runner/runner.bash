#!/usr/bin/env bash
#!/usr/bin/env bash

# ==============================================================================
# Filename: local_test_runner.bash
# Description:
#   This script provides a unified interface for executing tests within a
#   Dockerized test environment. It supports running unit tests, integration
#   tests, code coverage analysis, and GitHub Actions workflow simulations.
#
# Purpose:
#   - Standardizes the execution of test cases across different environments.
#   - Provides a containerized execution context, ensuring reproducibility.
#   - Supports multiple test execution modes (unit, integration, workflow, coverage).
#   - Automates the cleanup of test containers to prevent resource leaks.
#
# Usage:
#   bash test/local_test_runner.bash --test <test_function> [options]
#
# Options:
#   --test <test_function>   Specify the test function to execute (required).
#   --coverage               Run code coverage analysis using kcov.
#   --workflow               Execute tests via GitHub Actions workflow.
#   --bats-flags "<flags>"   Pass additional flags to BATS test execution.
#
# Examples:
#   # Run unit tests for the parser
#   bash test/local_test_runner.bash --test unit_test_parser
#
#   # Run unit tests and capture code coverage
#   bash test/local_test_runner.bash --test unit_test_parser --coverage
#
#   # Run integration tests via GitHub Actions workflow
#   bash test/local_test_runner.bash --test integration_test_parser --workflow
#
#   # Run unit tests with custom BATS flags
#   bash test/local_test_runner.bash --test unit_test_parser --bats-flags "--timing"
#
# Requirements:
#   - Docker installed and running
#   - The test container (robertportelli/test-readiluks:latest) available
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

declare -A CONFIG=(
    [BASE_DIR]="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    [IMAGENAME]="robertportelli/test-readiluks:latest"
    [DOCKERIMAGE]="ubuntu-latest=${CONFIG[IMAGENAME]}"
    [TEST]=""
    [COVERAGE]=false
    [WORKFLOW]=false
    [BATS_FLAGS]=""
    [DIND_FILE]="docker/test/Docker.dind"
    [DIND_IMAGE]="test-readiluks-dind"
    [DIND_CONTAINER]="test-readiluks-dind-container"
)

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

load_libraries() {
    source "$BASEDIR/test/local_test_runner/lib/_parser.bash"
    source "$BASEDIR/test/local_test_runner/lib/_docker-in-docker.bash"
    #source "$BASEDIR/test/local_test_runner/lib/_run-in-docker.bash"
    #source "$BASEDIR/test/local_test_runner/lib/_run-test.bash"
}


run_in_docker() {
    local cmd="$1"

    # Ensure DinD is running
    start_dind

    # Sanity check: Ensure the test-readiluks image exists inside DinD
    if ! docker exec "${CONFIG[DIND_CONTAINER]}" docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "${CONFIG[IMAGENAME]}"; then
        echo "❌ Image '${CONFIG[IMAGENAME]}' is missing inside DinD. Aborting."
        exit 1
    fi
     # Run the test container inside DinD and correctly capture its ID
    CONTAINER_ID=$(docker exec "${CONFIG[DIND_CONTAINER]}" docker run -d \
        --security-opt=no-new-privileges \
        --cap-drop=ALL \
        -v "${CONFIG[BASE_DIR]}:${CONFIG[BASE_DIR]}:ro" \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -w "${CONFIG[BASE_DIR]}" \
        --user "$(id -u):$(id -g)" \
        "${CONFIG[IMAGENAME]}" bash -c "$cmd")

    # Ensure CONTAINER_ID is not empty
    if [[ -z "$CONTAINER_ID" ]]; then
        echo "❌ Failed to start test container inside DinD. Aborting."
        exit 1
    fi

    # Attach to the container logs
    docker exec "${CONFIG[DIND_CONTAINER]}" docker logs -f "$CONTAINER_ID"

    # Ensure the test container is properly cleaned up after execution
    docker exec "${CONFIG[DIND_CONTAINER]}" docker stop "$CONTAINER_ID" > /dev/null 2>&1
    docker exec "${CONFIG[DIND_CONTAINER]}" docker rm -f "$CONTAINER_ID" > /dev/null 2>&1
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

test_create_device() {
    docker run --rm -it --privileged --user root "${CONFIG[IMAGENAME]}" bash
}

test_bats_common_setup() {
    local source_file="${CONFIG[BASE_DIR]}/lib/_common_setup.bash"
    local test_file="${CONFIG[BASE_DIR]}/unit/test_common_setup.bats"
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

cleanup() {
    if [[ -f /tmp/test_container_id ]]; then
        CONTAINER_ID=$(cat /tmp/test_container_id)
        if docker ps -a -q | grep -q "$CONTAINER_ID"; then
            echo "🧹 Cleaning up test container: $CONTAINER_ID"
            docker stop "$CONTAINER_ID" > /dev/null 2>&1 && docker rm -f "$CONTAINER_ID" > /dev/null 2>&1 || echo "⚠️ Failed to remove container."
        fi
        rm -f /tmp/test_container_id
    else
        echo "✅ No test container to clean up."
    fi
}


main() {
    load_libraries
    parse_arguments "$@"

    # Ensure CONFIG[TEST] is a valid function before executing it
    if declare -F "${CONFIG[TEST]}" >/dev/null; then
        "${CONFIG[TEST]}"

        # Only set the cleanup trap if a container was started
        if [[ -f "/tmp/test_container_id" ]]; then
            trap cleanup EXIT
        fi
    else
        echo "Error: '${CONFIG[TEST]}' is not a valid test function"
        exit 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
