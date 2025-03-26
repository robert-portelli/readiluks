# ==============================================================================
# Filename: test/local_test_runner/lib/_run-inner-sysd.bash
# ------------------------------------------------------------------------------
# Description:
#   Manages the execution of an ephemeral systemd-based test container inside the
#   outer Docker-in-Docker (DinD) environment. Handles the creation and cleanup of a
#   loopback device on the host, which is passed through to the inner container for
#   isolated block device testing.
#
# Purpose:
#   - Starts a systemd container inside DinD for each test case.
#   - Waits for systemd to become fully operational before running the test.
#   - Creates a loopback device on the host using an image file to simulate a block device.
#   - Passes the loopback device to the inner container for use in tests.
#   - Executes the provided command inside the systemd container and prints output.
#   - Stops and removes the container after execution to ensure clean state.
#   - Cleans up the loopback device and temporary image file to prevent resource leakage.
#
# Functions:
#   - create_test_device:
#       Creates a temporary image file, sets up a loopback device, and stores its reference.
#   - cleanup_test_device:
#       Detaches the loopback device, removes the temporary image file, and validates cleanup.
#   - run_systemd_container:
#       Ensures DinD is running, verifies the systemd image exists, creates the test device,
#       starts the container, waits for systemd readiness, runs the test command,
#       and performs cleanup of the container and device.
#
# Usage:
#   source "$BASEDIR/test/local_test_runner/lib/_run-inner-sysd.bash"
#   run_systemd_container "<command>"
#
# Example:
#   # Run a Bats test inside an ephemeral systemd container
#   run_systemd_container "bats test/local_test_runner/unit/test_parser.bats"
#
# Requirements:
#   - Requires `_manage_outer_docker.bash` to manage the outer DinD container.
#   - Requires `_runner-config.bash` to initialize CONFIG with required image/container names.
#   - Docker must be installed and accessible on the host.
#   - Assumes the outer DinD container will launch if not already running.
#
# Author:
#   Robert Portelli
#   Repository: https://github.com/robert-portelli/readiluks
#
# Version:
#   See repository tags or release notes.
#
# License:
#   See LICENSE.md in the repository.
#   See commit history via `git log`.
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

run_systemd_container() {
    local cmd="$1"

    # Ensure outer container (DinD) is running
    start_outer_container

    # Verify systemd image exists inside DinD
    # shellcheck disable=SC2153
    if ! docker exec "${CONFIG[OUTER_CONTAINER]}" docker images --format "{{.Repository}}:{{.Tag}}" |
         grep -q "${CONFIG[SYSTEMD_IMAGE]}"; then
        echo "❌ Image '${CONFIG[SYSTEMD_IMAGE]}' is missing inside ${CONFIG[OUTER_CONTAINER]}. Aborting."
        exit 1
    fi

    create_test_device

    echo "🚀 Starting ephemeral systemd container..."
    local CONTAINER_ID
    CONTAINER_ID=$(docker exec "${CONFIG[OUTER_CONTAINER]}" docker run -d \
        --privileged \
        --cgroupns=host \
        --user "$(id -u):$(id -g)" \
        --tmpfs /tmp --tmpfs /run --tmpfs /run/lock \
        -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
        -v "${CONFIG[BASE_DIR]}:${CONFIG[BASE_DIR]}:ro" \
        -v /var/run/docker.sock:/var/run/docker.sock \
        --device="${INCONFIG[TEST_DEVICE]}" \
        -e "TEST_DEVICE=${INCONFIG[TEST_DEVICE]}" \
        -w "${CONFIG[BASE_DIR]}" \
        "${CONFIG[SYSTEMD_IMAGE]}")

    if [[ -z "$CONTAINER_ID" ]]; then
        echo "❌ Failed to start systemd container inside DinD."
        cleanup_test_device
        exit 1
    fi

    echo "⏳ Waiting for systemd to become ready inside ephemeral container..."
    for i in {1..10}; do
        local status
        status=$(docker exec "${CONFIG[OUTER_CONTAINER]}" \
            docker exec "$CONTAINER_ID" systemctl is-system-running 2>/dev/null || true)

        if [[ "$status" == "running" ]]; then
            echo "✅ systemd is fully running in test container."
            break
        fi

        echo "   ⌛ systemd state: ${status:-unavailable}, retrying ($i/10)..."
        sleep 1
    done

    if [[ "$status" != "running" ]]; then
        echo "❌ systemd failed to become ready inside test container."
        docker exec "${CONFIG[OUTER_CONTAINER]}" docker rm -f "$CONTAINER_ID" >/dev/null 2>&1
        cleanup_test_device
        return 1
    fi

    echo "▶️ Running test command inside systemd container..."
    docker exec "${CONFIG[OUTER_CONTAINER]}" \
        docker exec "$CONTAINER_ID" bash -c "$cmd"

    echo "🧼 Cleaning up container and loop device..."
    docker exec "${CONFIG[OUTER_CONTAINER]}" docker stop "$CONTAINER_ID" >/dev/null 2>&1
    docker exec "${CONFIG[OUTER_CONTAINER]}" docker rm -f "$CONTAINER_ID" >/dev/null 2>&1
    cleanup_test_device
}
