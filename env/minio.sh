#!/bin/bash
# MinIO S3-compatible storage pod management
#
# STARTUP INFO:
# - Startup Time: 30-40 seconds (includes network setup)
# - Health Check: http://localhost:9000/minio/health/live
# - Memory Usage: ~256MB (configurable via MINIO_MEMORY)
# - No timeout needed (under 1 minute)
#
# OBSERVED INITIALIZATION PHASES:
# 1. Network setup (~10s)
# 2. Container start (~5s)
# 3. Volume creation (~5s)
# 4. Storage backend init (~5s)
# 5. API server ready (~5s)
# 6. Console available immediately
#
# TROUBLESHOOTING:
# - Check logs: ./setup-env.sh logs minio
# - Storage issues: Verify volume mounting
# - Access issues: Check MINIO_ROOT_USER/PASSWORD
# - Port conflicts: Verify 9000/9001 ports available

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/common.sh"

# Use .env configuration variables
CONTAINER_NAME="$MINIO_CONTAINER_NAME"
IMAGE="$MINIO_IMAGE"
PORT="$MINIO_PORT"
CONSOLE_PORT="$MINIO_CONSOLE_PORT"
VOLUME_NAME="$MINIO_VOLUME_NAME"

start_minio() {
    print_header "🗄️ STARTING MINIO"
    ensure_network

    if start_existing_container "$CONTAINER_NAME"; then
        wait_for_service "MinIO" "http://localhost:$PORT/minio/health/live"
        print_color "$BLUE" "Console: http://localhost:$CONSOLE_PORT (minioadmin/minioadmin)"
        return 0
    fi

    podman volume create "$VOLUME_NAME" >/dev/null 2>&1 || true

    print_color "$YELLOW" "Creating MinIO container..."
    podman run -d \
        --name "$CONTAINER_NAME" \
        --network "$NETWORK_NAME" \
        -p "${PORT}:9000" \
        -p "${CONSOLE_PORT}:9001" \
        --memory="$MINIO_MEMORY" \
        -v "$VOLUME_NAME:/data" \
        -e "MINIO_ROOT_USER=$MINIO_ROOT_USER" \
        -e "MINIO_ROOT_PASSWORD=$MINIO_ROOT_PASSWORD" \
        "$IMAGE" server /data --console-address ":9001" >/dev/null

    print_color "$GREEN" "✓ MinIO container created"
    wait_for_service "MinIO" "http://localhost:$PORT/minio/health/live"
    print_color "$BLUE" "Console: http://localhost:$CONSOLE_PORT (minioadmin/minioadmin)"
}

stop_minio() {
    print_header "🛑 STOPPING MINIO"
    stop_container "$CONTAINER_NAME"
}

logs_minio() {
    get_container_logs "$CONTAINER_NAME" "${1:-20}"
}

status_minio() {
    print_header "📊 MINIO STATUS"

    if container_running "$CONTAINER_NAME"; then
        print_color "$GREEN" "✓ MinIO container is running"
        print_color "$BLUE" "Container: $CONTAINER_NAME"
        print_color "$BLUE" "S3 API: http://localhost:$PORT"
        print_color "$BLUE" "Console: http://localhost:$CONSOLE_PORT"
        print_color "$BLUE" "Credentials: $MINIO_ROOT_USER/$MINIO_ROOT_PASSWORD"

        # Check if API is responding
        if curl -sf "http://localhost:$PORT/minio/health/live" >/dev/null 2>&1; then
            print_color "$GREEN" "✓ S3 API is accessible"
        else
            print_color "$YELLOW" "⚠ S3 API not yet ready"
        fi
    elif container_exists "$CONTAINER_NAME"; then
        print_color "$YELLOW" "⚠ MinIO container exists but is not running"
        print_color "$BLUE" "Run: $0 start"
    else
        print_color "$RED" "✗ MinIO container does not exist"
        print_color "$BLUE" "Run: $0 start"
    fi
}

case "${1:-start}" in
    start) start_minio ;;
    stop) stop_minio ;;
    restart) stop_minio && start_minio ;;
    status) status_minio ;;
    logs) logs_minio "$2" ;;
    *) echo "Usage: $0 {start|stop|restart|status|logs}" ;;
esac