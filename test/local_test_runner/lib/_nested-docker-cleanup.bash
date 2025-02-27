# ==============================================================================
# Filename: test/local_test_runner/lib/_nested-docker-cleanup.bash
# ------------------------------------------------------------------------------
# Description:
#   Provides a robust cleanup mechanism to ensure no orphaned test containers
#   remain and the loopback test device is properly cleaned up after execution.
#
# Purpose:
#   - Ensures all test containers tracked in `/tmp/test_container_id` are removed.
#   - Handles stale container IDs gracefully and logs cleanup events for debugging.
#   - Cleans up the loopback device and associated image file used during tests.
#   - Verifies that the loopback device is detached and the image file is deleted.
#
# Functions:
#   - nested_container_cleanup: Cleans up all test containers managed by the
#     test runner by reading `/tmp/test_container_id`.
#   - cleanup_test_device: Handles the cleanup of the loopback device and
#     associated test image file, ensuring no residual resources remain.
#
# Usage:
#   source "$BASEDIR/test/local_test_runner/lib/_nested-docker-cleanup.bash"
#   nested_container_cleanup
#   cleanup_test_device
#
# Example:
#   # Register cleanup to run on script exit
#   trap "nested_container_cleanup; cleanup_test_device" EXIT
#
# Requirements:
#   - Must be sourced before calling `nested_container_cleanup` or `cleanup_test_device`.
#   - Requires `_run-in-docker.bash` to ensure test containers are properly tracked.
#   - Requires `_runner-config.bash` for test container and loopback device settings.
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


nested_container_cleanup() {
    local container_id_file="/tmp/test_container_id"

    if [[ -f "$container_id_file" ]]; then
        echo "🧹 Cleaning up test containers listed in $container_id_file..."

        while IFS= read -r container_id; do
            # Ensure the container ID is valid
            if [[ -n "$container_id" ]] && docker ps -a -q | grep -q "$container_id"; then
                echo "   🔄 Stopping and removing container: $container_id"
                docker stop "$container_id" > /dev/null 2>&1 && docker rm -f "$container_id" > /dev/null 2>&1
                if docker stop "$container_id" > /dev/null 2>&1 && docker rm -f "$container_id" > /dev/null 2>&1; then
                    echo "   ✅ Successfully removed: $container_id"
                else
                    echo "   ⚠️ Failed to remove container: $container_id"
                fi
            else
                echo "   ⚠️ No running container found with ID: $container_id"
            fi
        done < "$container_id_file"

        # Remove the container ID tracking file
        rm -f "$container_id_file"
        echo "✅ Cleanup completed."
    else
        echo "✅ No test container to clean up."
    fi
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

    if [[ -b "${CONFIG[TEST_DEVICE]}" || -e "${CONFIG[TEST_FILE]}" ]]; then
        echo "❌ Failed Test Device Cleanup"
        return 1
    fi

    echo "✅ Cleanup complete."
}
