# ==============================================================================
# Filename: test/local_test_runner/lib/_run-in-docker.bash
# ------------------------------------------------------------------------------
# Description:
#   Manages the execution of a nested test container inside the outer Docker-in-Docker
#   (DinD) environment. Handles the creation and cleanup of a loopback device on the host,
#   which is passed through to the inner test container for safe and isolated device testing.
#
# Purpose:
#   - Starts a test container inside DinD (launched via a custom outer DinD container).
#   - Creates a loopback device on the host using an image file to simulate a block device.
#   - Passes the loopback device to the test container inside DinD for use in tests.
#   - Ensures the required test image (`${CONFIG[HARNESS_IMAGE]}`) is available inside DinD
#     before launching the test container.
#   - Executes the provided command inside the test container and streams logs in real time.
#   - Stops and removes the test container after execution to ensure a clean environment.
#   - Cleans up the loopback device and temporary image file to prevent resource leakage.
#
# Functions:
#   - create_test_device:
#       Creates a temporary image file, sets up a loopback device, and registers it in CONFIG.
#   - cleanup_test_device:
#       Detaches the loopback device, removes the temporary image file, and verifies cleanup.
#   - run_in_docker:
#       Ensures DinD is running, verifies the test image exists inside DinD,
#       creates the test device, runs the test container, streams logs, and performs cleanup.
#
# Usage:
#   source "$BASEDIR/test/local_test_runner/lib/_run-in-docker.bash"
#   run_in_docker "<command>"
#
# Example:
#   # Run a Bats test suite inside the nested test container
#   run_in_docker "bats test/unit/test_parser.bats"
#
# Requirements:
#   - Requires `_manage_outer_docker.bash` to start and manage the outer DinD container.
#   - Requires `_runner-config.bash` to initialize global configuration variables in CONFIG.
#   - Docker must be installed and running on the host.
#   - Assumes the DinD container is already running and ready, or `start_dind` will initialize it.
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

declare -gA INCONFIG=(
    [TEST_FILE_SIZE]="1024M"
    [TEST_FILES]=""
    [TEST_DEVICES]=""
)

create_test_device() {
    local img_file

    img_file="/tmp/readiluks-test-device-file-$(uuidgen | cut -c -5).img"
    truncate -s "${INCONFIG[TEST_FILE_SIZE]}" "$img_file"

    # Create a loopback device on the host
    local loop_device
    loop_device=$(sudo losetup --show -fP "$img_file" 2>/dev/null)
    if [[ -z "$loop_device" ]]; then
        echo "❌ Failed to create loopback device. Aborting."
        rm -f "$img_file"
        exit 1
    fi
    echo "✅ Loopback device created: $loop_device"

    INCONFIG[TEST_FILE]="$img_file"
    INCONFIG[TEST_DEVICE]="$loop_device"

}

cleanup_test_device() {
    echo "🧹 Cleaning up loopback device and image file..."

    if losetup -j "${INCONFIG[TEST_FILE]}" | grep -q "${INCONFIG[TEST_DEVICE]}"; then
        echo "Detaching loop device ${INCONFIG[TEST_DEVICE]}..."
        losetup -d "${INCONFIG[TEST_DEVICE]}" || echo "❌ Failed to detach loop device"
    fi

    if [[ -f "${INCONFIG[TEST_FILE]}" ]]; then
        echo "Removing image file ${INCONFIG[TEST_FILE]}..."
        rm -f "${INCONFIG[TEST_FILE]}" || echo "❌ Failed to remove image file"
    fi

    if losetup -l | grep -q "${INCONFIG[TEST_DEVICE]}" || [[ -f "${INCONFIG[TEST_FILE]}" ]]; then
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
    # shellcheck disable=SC2153
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
        --device="${INCONFIG[TEST_DEVICE]}" \
        -e "TEST_DEVICE=${INCONFIG[TEST_DEVICE]}" \
        -w "${CONFIG[BASE_DIR]}" \
        --user "$(id -u):$(id -g)" \
        "${CONFIG[HARNESS_IMAGE]}" bash -c "$cmd")

    # Ensure CONTAINER_ID is not empty
    if [[ -z "$CONTAINER_ID" ]]; then
        echo "❌ Failed to start test container inside DinD. Aborting."
        exit 1
    fi

    # Attach to the container logs
    docker exec "${CONFIG[OUTER_CONTAINER]}" docker logs -f "$CONTAINER_ID"

    # Ensure the test container is properly cleaned up after execution
    docker exec "${CONFIG[OUTER_CONTAINER]}" docker stop "$CONTAINER_ID" > /dev/null 2>&1
    docker exec "${CONFIG[OUTER_CONTAINER]}" docker rm -f "$CONTAINER_ID" > /dev/null 2>&1
    cleanup_test_device
}
