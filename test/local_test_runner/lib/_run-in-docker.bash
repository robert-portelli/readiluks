# ==============================================================================
# Filename: test/local_test_runner/lib/_run-in-docker.bash
# ------------------------------------------------------------------------------
# Description:
#   Manages the execution of a nested test container inside the Docker-in-Docker
#   (DinD) environment. Ensures the test container starts, runs, and is cleaned up.
#
# Purpose:
#   - Starts a test container inside DinD (`docker:dind` with custom setup) and executes the provided command.
#   - Uses the test image `robertportelli/test-readiluks:latest`, built from `docker/test/Dockerfile`.
#   - Ensures the test image is available inside DinD before running tests.
#   - Captures and streams logs from the test container in real time.
#   - Properly cleans up the test container after execution to avoid resource leaks.
#
# Options:
#   This script does not accept command-line options. It is sourced by the test
#   runner and its functions.
#
# Usage:
#   source "$BASEDIR/test/local_test_runner/lib/_run-in-docker.bash"
#   run_in_docker "<command>"
#
# Example(s):
#   # Run a test script inside a nested container
#   run_in_docker "bats test/unit/test_parser.bats"
#
# Requirements:
#   - Must be sourced before calling `run_in_docker()`.
#   - Requires `_docker-in-docker.bash` for ensuring DinD is running.
#   - Requires `_runner-config.bash` for global configuration variables.
#   - Assumes the DinD container is running and the test image is available.
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
