# ==============================================================================
# Filename: test/local_test_runner/lib/_manage_outer_docker.bash
# ------------------------------------------------------------------------------
# Description:
#   Manages the lifecycle of the outer Docker-in-Docker (DinD) container used for
#   isolated test execution. Ensures that outer DinD is running and that the required
#   test image is available inside it.
#
# Purpose:
#   - Starts the outer DinD container (`docker:dind` with custom setup) if it is not already running.
#   - Ensures the test image (`robertportelli/test-readiluks:latest`) is available inside DinD.
#   - Provides an isolated Docker environment for executing tests.
#   - Uses the Dockerfile at `docker/test/Dockerfile.outer` to build the DinD image.
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
