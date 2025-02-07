cleanup() {
    if [[ -f /tmp/test_container_id ]]; then
        CONTAINER_ID=$(cat /tmp/test_container_id)
        if docker ps -a -q | grep -q "$CONTAINER_ID"; then
            echo "🧹 Cleaning up test container: $CONTAINER_ID"
            docker stop "$CONTAINER_ID" > /dev/null 2>&1 && docker rm -f "$CONTAINER_ID" > /dev/null 2>&1 || echo "⚠️ Failed to remove container."
        fi
        rm -f /tmp/test_container_id
    else
        echo "✅ No test container to clean up."
    fi
}
