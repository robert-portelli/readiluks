# ==============================================================================
# Filename: test/local_test_runner/lib/_manage_outer_docker.bash
# ------------------------------------------------------------------------------
# Description:
#   Manages the lifecycle of the outer Docker-in-Docker (DinD) container used for
#   isolated test execution. Ensures that the DinD container is running and that
#   the required test image is available inside the DinD environment.
#
# Purpose:
#   - Starts the outer DinD container (using a custom Dockerfile) if it is not already running.
#   - Builds the DinD image from `docker/test/Dockerfile.outer` if it does not exist.
#   - Waits for the Docker daemon inside DinD to become ready before proceeding.
#   - Ensures the test image (`${CONFIG[IMAGENAME]}`) is available inside DinD by:
#       * Checking for the image inside DinD.
#       * Building the image locally if it doesn't exist.
#       * Pulling the image from Docker Hub as a fallback if build fails.
#       * Saving, copying, and loading the image into DinD if not already present.
#   - Provides an isolated Docker environment for executing nested test containers,
#     enabling safe testing of `readiluks` without impacting the host system.
#
# Options:
#   This script does not accept command-line options. It is sourced by the test
#   runner and its functions.
#
# Usage:
#   source "$BASEDIR/test/local_test_runner/lib/_manage_outer_docker.bash"
#   start_dind
#
# Example(s):
#   # Ensure DinD is running and the test image is available
#   start_dind
#
# Requirements:
#   - Must be sourced before calling `start_dind()`.
#   - Requires Docker to be installed and running on the host.
#   - Assumes the DinD container is used for executing nested test containers.
#   - Relies on `${CONFIG[DIND_IMAGE]}`, `${CONFIG[DIND_CONTAINER]}`, and related variables
#     to be properly initialized before invoking `start_dind()`.
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

start_dind() {
    echo "🚀 Ensuring Outer Docker-in-Docker container is running..."

    # Check if the DinD image exists, build if necessary
    if ! docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "${CONFIG[DIND_IMAGE]}"; then
        echo "🔧 Building DinD image..."
        docker build --load -t "${CONFIG[DIND_IMAGE]}" -f "${CONFIG[DIND_FILE]}" .
    fi

    # Start DinD container if not already running
    if ! docker ps --format "{{.Names}}" | grep -q "${CONFIG[DIND_CONTAINER]}"; then
        docker run --rm -d \
            --privileged \
            -v "$(pwd):${CONFIG[BASE_DIR]}:ro" \
            --name "${CONFIG[DIND_CONTAINER]}" \
            "${CONFIG[DIND_IMAGE]}"
    fi

    # Wait until Docker daemon inside DinD is ready
    until docker exec "${CONFIG[DIND_CONTAINER]}" docker info >/dev/null 2>&1; do
        echo "⌛ Waiting for DinD to start..."
        sleep 1
    done

    echo "✅ DinD is ready!"


    # Ensure the test image is inside DinD
    if ! docker exec "${CONFIG[DIND_CONTAINER]}" docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "${CONFIG[IMAGENAME]}"; then
        echo "📦 ${CONFIG[IMAGENAME]} not found in DinD. Preparing to transfer..."

        # Check if the image exists locally
        if ! docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "${CONFIG[IMAGENAME]}"; then
            echo "⚠️  Image ${CONFIG[IMAGENAME]} not found locally. Attempting to build first..."

            # Try to build the image locally first
            if ! docker build --load -t "${CONFIG[IMAGENAME]}" -f docker/test/Dockerfile.inner .; then
                echo "❌ Build failed. Attempting to pull from Docker Hub..."

                # If build fails, attempt to pull from Docker Hub
                if ! docker pull "${CONFIG[IMAGENAME]}"; then
                    echo "❌ Failed to build or pull ${CONFIG[IMAGENAME]}. Aborting image transfer."
                    exit 1
                fi
            fi
        fi

        # At this point, the image must exist locally, so transfer it into DinD
        echo "📦 Transferring ${CONFIG[IMAGENAME]} to DinD..."
        docker save -o test-readiluks.tar "${CONFIG[IMAGENAME]}"
        docker cp test-readiluks.tar "${CONFIG[DIND_CONTAINER]}:/test-readiluks.tar"
        docker exec "${CONFIG[DIND_CONTAINER]}" docker load -i /test-readiluks.tar
        echo "✅ Image ${CONFIG[IMAGENAME]} is now available inside DinD!"
        rm -f test-readiluks.tar  # Cleanup local tar file

    else
        echo "✅ Image ${CONFIG[IMAGENAME]} already exists inside DinD."
    fi
}
