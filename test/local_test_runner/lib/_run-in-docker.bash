# ==============================================================================
# Filename: test/local_test_runner/lib/_run-in-docker.bash
# ------------------------------------------------------------------------------
# Description:
#   Manages the execution of a nested test container inside the outer Docker-in-Docker
#   (DinD) environment, including loopback device management for testing.
#
# Purpose:
#   - Starts a test container inside DinD (`docker:dind` with custom setup).
#   - Prepares a loopback device on the host and passes it to the container.
#   - Executes the provided command inside the test container.
#   - Ensures the test image `robertportelli/test-readiluks:latest` is available
#     inside DinD before running tests.
#   - Captures and streams logs from the test container in real time.
#   - Properly cleans up the test container and loopback device after execution
#     to avoid resource leaks.
#
# Functions:
#   - create_test_device: Creates and configures a loopback device on the host.
#   - cleanup_test_device: Cleans up the loopback device and associated resources.
#   - run_in_docker: Manages the lifecycle of the test container inside DinD.
#
# Usage:
#   source "$BASEDIR/test/local_test_runner/lib/_run-in-docker.bash"
#   run_in_docker "<command>"
#
# Example:
#   # Run a test script inside a nested container
#   run_in_docker "bats test/unit/test_parser.bats"
#
# Requirements:
#   - Requires `_manage_outer_docker.bash` for ensuring DinD is running.
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


create_test_device() {
    # Create a temporary image file
    local img_file

    img_file="/tmp/readiluks-test-device-file.img"
    truncate -s "${CONFIG[TEST_FILE_SIZE]}" "$img_file"

    # Create a loopback device on the host
    local loop_device
    loop_device=$(sudo losetup --show -fP "$img_file" 2>/dev/null)
    if [[ -z "$loop_device" ]]; then
        echo "❌ Failed to create loopback device. Aborting."
        rm -f "$img_file"
        exit 1
    fi
    echo "✅ Loopback device created: $loop_device"

    CONFIG[TEST_FILE]="$img_file"
    CONFIG[TEST_DEVICE]="$loop_device"

}

cleanup_test_device() {
    echo "🧹 Cleaning up loopback device and image file..."

    if losetup -j "${CONFIG[TEST_FILE]}" | grep -q "${CONFIG[TEST_DEVICE]}"; then
        echo "Detaching loop device ${CONFIG[TEST_DEVICE]}..."
        losetup -d "${CONFIG[TEST_DEVICE]}" || echo "❌ Failed to detach loop device"
    fi

    if [[ -f "${CONFIG[TEST_FILE]}" ]]; then
        echo "Removing image file ${CONFIG[TEST_FILE]}..."
        rm -f "${CONFIG[TEST_FILE]}" || echo "❌ Failed to remove image file"
    fi

    if losetup -l | grep -q "${CONFIG[TEST_DEVICE]}" || [[ -f "${CONFIG[TEST_FILE]}" ]]; then
        echo "❌ Failed Test Device Cleanup"
        return 1
    fi

    echo "✅ Cleanup complete."
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
    cleanup_test_device
}
