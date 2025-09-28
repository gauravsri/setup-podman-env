#!/bin/bash
# MinIO S3-compatible storage pod management

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

case "${1:-start}" in
    start) start_minio ;;
    stop) stop_minio ;;
    restart) stop_minio && start_minio ;;
    logs) logs_minio "$2" ;;
    *) echo "Usage: $0 {start|stop|restart|logs}" ;;
esac