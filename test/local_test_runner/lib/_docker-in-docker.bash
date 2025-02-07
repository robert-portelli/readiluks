start_dind() {
    echo "🚀 Ensuring Docker-in-Docker container is running..."

    # Check if the DinD image exists, build if necessary
    if ! docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "${CONFIG[DIND_IMAGE]}"; then
        echo "🔧 Building DinD image..."
        docker build --load -t "${CONFIG[DIND_IMAGE]}" -f "${CONFIG[DIND_FILE]}" .
    fi

    # Start DinD container if not already running
    if ! docker ps --format "{{.Names}}" | grep -q "${CONFIG[DIND_CONTAINER]}"; then
        docker run --rm -d --privileged \
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
            if ! docker build --load -t "${CONFIG[IMAGENAME]}" -f docker/test/Dockerfile .; then
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
