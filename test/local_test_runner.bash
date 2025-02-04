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
    [DOCKERIMAGE]="ubuntu-latest=${CONFIG[IMAGENAME]}"
    [TEST]=""
    [COVERAGE]=false
    [WORKFLOW]=false
    [BATS_FLAGS]=""
)

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

run_in_docker() {
    local cmd="$1"

    # Check if the image exists locally
    if ! docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "${CONFIG[IMAGENAME]}"; then
        echo "Image '${CONFIG[IMAGENAME]}' not found locally. Attempting to build..."

        # Try building locally first
        if ! docker build -t "${CONFIG[IMAGENAME]}" -f docker/test/Dockerfile .; then
            echo "Local build failed. Attempting to pull from Docker Hub..."

            # If build fails, attempt to pull
            if ! docker pull "${CONFIG[IMAGENAME]}"; then
                echo "Failed to pull Docker image '${CONFIG[IMAGENAME]}'."
                exit 1
            fi
        fi
    fi

     # Start the test container and capture its ID
    CONTAINER_ID=$(docker run --rm -d \
        --security-opt=no-new-privileges \
        --cap-drop=ALL \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v "$(pwd):${CONFIG[BASE_DIR]}:ro" \
        -w "${CONFIG[BASE_DIR]}" \
        --user "$(id -u):$(id -g)" \
        "${CONFIG[IMAGENAME]}" bash -c "$cmd")

    # Save container ID for cleanup
    echo "$CONTAINER_ID" > /tmp/test_container_id

    # Attach to the container so it runs in the foreground
    docker logs -f "$CONTAINER_ID"

    # Remove the container (Docker --rm flag ensures this is not needed in most cases)
    docker stop "$CONTAINER_ID" > /dev/null 2>&1 && docker rm -f "$CONTAINER_ID" > /dev/null 2>&1
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

test_bats_common_setup() {
    local source_file="${CONFIG[BASE_DIR]}/test/lib/_common_setup.bash"
    local test_file="${CONFIG[BASE_DIR]}/test/test_common_setup.bats"
    local workflow_event="workflow_dispatch"
    local workflow_job="test-bats-common-setup"

    run_test "$source_file" "$test_file" "$workflow_event" "$workflow_job"
}

unit_test_parser() {
    local source_file="${CONFIG[BASE_DIR]}/src/lib/_parser.bash"
    local test_file="${CONFIG[BASE_DIR]}/test/unit/test_parser.bats"
    local workflow_event="workflow_dispatch"
    local workflow_job="unit-test-parser"

    run_test "$source_file" "$test_file" "$workflow_event" "$workflow_job"
}

integration_test_parser() {
    local source_file="${CONFIG[BASE_DIR]}/src/main.bash"
    local test_file="${CONFIG[BASE_DIR]}/test/integration/test_parser.bats"
    local workflow_event="workflow_dispatch"
    local workflow_job="integration-test-parser"

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
