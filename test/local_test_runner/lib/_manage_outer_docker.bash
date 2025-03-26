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
#   - Ensures the test image (`${CONFIG[HARNESS_IMAGE]}`) is available inside DinD by:
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
#   start_outer_container
#
# Example(s):
#   # Ensure DinD is running and the test image is available
#   start_outer_container
#
# Requirements:
#   - Must be sourced before calling `start_outer_container()`.
#   - Requires Docker to be installed and running on the host.
#   - Assumes the DinD container is used for executing nested test containers.
#   - Relies on `${CONFIG[OUTER_IMAGE]}`, `${CONFIG[OUTER_CONTAINER]}`, and related variables
#     to be properly initialized before invoking `start_outer_container()`.
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

start_outer_container() {
    echo "🚀 Ensuring Outer Docker-in-Docker container is running..."

    # Check if the outer image exists, build if necessary
    if ! docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "${CONFIG[OUTER_IMAGE]}"; then
        echo "🔧 Building Outer image..."
        docker build --load -t "${CONFIG[OUTER_IMAGE]}" -f "${CONFIG[OUTER_DOCKERFILE]}" .
    fi

    # Start outer container if not already running
    if ! docker ps --format "{{.Names}}" | grep -q "${CONFIG[OUTER_CONTAINER]}"; then
        docker run --rm -d \
            --privileged \
            -v "$(pwd):${CONFIG[BASE_DIR]}:ro" \
            --name "${CONFIG[OUTER_CONTAINER]}" \
            "${CONFIG[OUTER_IMAGE]}"
    fi

    # Wait until Docker daemon inside DinD is ready
    until docker exec "${CONFIG[OUTER_CONTAINER]}" docker info >/dev/null 2>&1; do
        echo "⌛ Waiting for ${CONFIG[OUTER_CONTAINER]} to start..."
        sleep 1
    done

    echo "✅ ${CONFIG[OUTER_CONTAINER]} is ready!"

    #load_harness_image
    load_systemd_image
    #start_systemd_container
}

start_systemd_container() {
    echo "🧪 Ensuring long-running systemd container is running..."
    if ! docker exec "${CONFIG[OUTER_CONTAINER]}" docker ps --format "{{.Names}}" | grep -q "${CONFIG[SYSTEMD_CONTAINER]}"; then
        docker exec "${CONFIG[OUTER_CONTAINER]}" docker run -d \
            --privileged \
            --tmpfs /tmp --tmpfs /run --tmpfs /run/lock \
            -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
            --cgroupns=host \
            --name "${CONFIG[SYSTEMD_CONTAINER]}" \
            "${CONFIG[SYSTEMD_IMAGE]}"
        echo "✅ Systemd container started."
        echo "⏳ Waiting for systemd to become ready in container..."
        for i in {1..10}; do
            status=$(docker exec "${CONFIG[OUTER_CONTAINER]}" \
                docker exec "${CONFIG[SYSTEMD_CONTAINER]}" systemctl is-system-running 2>/dev/null || true)

            if [[ "$status" == "running" ]]; then
                echo "✅ systemd is fully running."
                return 0
            fi

            echo "   ⌛ systemd state: ${status:-unavailable}, retrying ($i/10)..."
            sleep 1
        done

        echo "❌ systemd failed to become ready after 10 seconds."
        return 1
    else
        echo "✅ Systemd container already running."
    fi

}

load_harness_image() {
    local image="${CONFIG[HARNESS_IMAGE]}"
    echo "📦 Checking for harness image: ${image}"

    if ! docker exec "${CONFIG[OUTER_CONTAINER]}" docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "${image}"; then
        echo "📦 ${image} not found in Outer container: ${CONFIG[OUTER_CONTAINER]}. Preparing to transfer..."

        if ! docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "${image}"; then
            echo "⚠️  Image ${image} not found locally. Attempting to build first..."
            if ! docker build --load -t "${image}" -f docker/test/Dockerfile.inner-harness .; then
                echo "❌ Build failed. Attempting to pull from Docker Hub..."
                docker pull "${image}" || {
                    echo "❌ Failed to build or pull ${image}. Aborting image transfer."
                    exit 1
                }
            fi
        fi

        docker save -o test-readiluks-harness.tar "${image}"
        docker cp test-readiluks-harness.tar "${CONFIG[OUTER_CONTAINER]}:/test-readiluks-harness.tar"
        docker exec "${CONFIG[OUTER_CONTAINER]}" docker load -i /test-readiluks-harness.tar
        rm -f test-readiluks-harness.tar
        echo "✅ Image ${image} is now available inside DinD!"
    else
        echo "✅ Image ${image} already exists inside DinD."
    fi
}

load_systemd_image() {
    local image="${CONFIG[SYSTEMD_IMAGE]}"
    echo "📦 Checking for systemd image: ${image}"

    if ! docker exec "${CONFIG[OUTER_CONTAINER]}" docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "${image}"; then
        echo "📦 ${image} not found in Outer container: ${CONFIG[OUTER_CONTAINER]}. Preparing to transfer..."

        if ! docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "${image}"; then
            echo "⚠️  Image ${image} not found locally. Attempting to build first..."
            if ! docker build --load -t "${image}" -f docker/test/Dockerfile.inner-systemd .; then
                echo "❌ Build failed. Attempting to pull from Docker Hub..."
                docker pull "${image}" || {
                    echo "❌ Failed to build or pull ${image}. Aborting image transfer."
                    exit 1
                }
            fi
        fi

        docker save -o test-readiluks-systemd.tar "${image}"
        docker cp test-readiluks-systemd.tar "${CONFIG[OUTER_CONTAINER]}:/test-readiluks-systemd.tar"
        docker exec "${CONFIG[OUTER_CONTAINER]}" docker load -i /test-readiluks-systemd.tar
        rm -f test-readiluks-systemd.tar
        echo "✅ Image ${image} is now available inside DinD!"
    else
        echo "✅ Image ${image} already exists inside DinD."
    fi
}
