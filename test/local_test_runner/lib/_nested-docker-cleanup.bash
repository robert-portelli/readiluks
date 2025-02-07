# ==============================================================================
# Filename: test/local_test_runner/lib/_nested-docker-cleanup.bash
# ------------------------------------------------------------------------------
# Description:
#   Provides a cleanup mechanism to ensure no orphaned test containers remain
#   after execution.
#
# Purpose:
#   - Ensures all test containers tracked in `/tmp/test_container_id` are removed.
#   - Handles stale container IDs gracefully.
#   - Logs cleanup events for debugging.
#
# Options:
#   This script does not accept command-line options. It is sourced by the test
#   runner and its functions.
#
# Usage:
#   source "$BASEDIR/test/local_test_runner/lib/_nested-docker-cleanup.bash"
#   cleanup
#
# Example(s):
#   # Register cleanup to run on script exit
#   trap cleanup EXIT
#
# Requirements:
#   - Must be sourced before calling `cleanup()`.
#   - Requires `_run-in-docker.bash` to ensure test containers are properly
#     tracked.
#   - Requires `_runner-config.bash` for test container settings.
#   - Assumes the test runner writes container IDs to `/tmp/test_container_id`.
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

cleanup() {
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
