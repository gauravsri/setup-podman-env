#!/bin/bash
# Dremio SQL Federation Engine pod management

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/common.sh"

# Use .env configuration variables
CONTAINER_NAME="$DREMIO_CONTAINER_NAME"
IMAGE="$DREMIO_IMAGE"
HTTP_PORT="$DREMIO_HTTP_PORT"
JDBC_PORT="$DREMIO_JDBC_PORT"
VOLUME_NAME="$DREMIO_VOLUME_NAME"

start_dremio() {
    print_header "⚡ STARTING DREMIO"
    ensure_network

    if start_existing_container "$CONTAINER_NAME"; then
        wait_for_service "Dremio" "http://localhost:$HTTP_PORT" "$DREMIO_STARTUP_TIMEOUT"
        print_color "$BLUE" "Web UI: http://localhost:$HTTP_PORT"
        print_color "$BLUE" "JDBC: jdbc:dremio:direct=localhost:$JDBC_PORT"
        return 0
    fi

    podman volume create "$VOLUME_NAME" >/dev/null 2>&1 || true

    print_color "$YELLOW" "Creating Dremio container (this may take time on low-end hardware)..."
    podman run -d \
        --name "$CONTAINER_NAME" \
        --network "$NETWORK_NAME" \
        -p "${HTTP_PORT}:8080" \
        -p "${JDBC_PORT}:9047" \
        -p "31010:31010" \
        --memory="$DREMIO_MEMORY" \
        -v "$VOLUME_NAME:/opt/dremio/data" \
        "$IMAGE" >/dev/null

    print_color "$GREEN" "✓ Dremio container created"
    wait_for_service "Dremio" "http://localhost:$HTTP_PORT" "$DREMIO_STARTUP_TIMEOUT"
    print_color "$BLUE" "Web UI: http://localhost:$HTTP_PORT"
    print_color "$BLUE" "JDBC: jdbc:dremio:direct=localhost:$JDBC_PORT"
}

stop_dremio() {
    print_header "🛑 STOPPING DREMIO"
    stop_container "$CONTAINER_NAME"
}

logs_dremio() {
    get_container_logs "$CONTAINER_NAME" "${1:-20}"
}

case "${1:-start}" in
    start) start_dremio ;;
    stop) stop_dremio ;;
    restart) stop_dremio && start_dremio ;;
    logs) logs_dremio "$2" ;;
    *) echo "Usage: $0 {start|stop|restart|logs}" ;;
esac