#!/bin/bash
# Dremio SQL Federation Engine pod management
#
# STARTUP INFO:
# - Startup Time: 3-12 minutes (very slow, memory-intensive JVM initialization)
# - Health Check: http://localhost:8080 (default)
# - Timeout: Configurable via DREMIO_STARTUP_TIMEOUT (default: 720s/12min)
# - Memory Usage: ~1GB (configurable via DREMIO_MEMORY)
#
# OBSERVED INITIALIZATION PHASES:
# 1. Container start (~10s)
# 2. JVM initialization (~30-60s)
# 3. Metadata store initialization (~2-5 minutes)
# 4. Catalog loading and GC optimization (~2-4 minutes)
# 5. Web server startup (~30-60s)
# 6. Service registration and discovery (~10-30s)
#
# TROUBLESHOOTING:
# - Be patient! Dremio startup can take 3-12 minutes (observed behavior)
# - Check logs: ./setup-env.sh logs dremio
# - Monitor resources: podman stats $CONTAINER_NAME
# - Watch for GC activity: Normal during initialization
# - Common issues: Out of memory, slow disk I/O, insufficient CPU
# - Low-end hardware: Allow up to 15 minutes for first startup

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

status_dremio() {
    print_header "📊 DREMIO STATUS"

    if container_running "$CONTAINER_NAME"; then
        print_color "$GREEN" "✓ Dremio container is running"
        print_color "$BLUE" "Container: $CONTAINER_NAME"
        print_color "$BLUE" "Web UI: http://localhost:$HTTP_PORT"
        print_color "$BLUE" "JDBC: jdbc:dremio:direct=localhost:$JDBC_PORT"

        # Check if web UI is responding
        if curl -sf "http://localhost:$HTTP_PORT" >/dev/null 2>&1; then
            print_color "$GREEN" "✓ Web UI is accessible"
        else
            print_color "$YELLOW" "⚠ Web UI not yet ready (startup can take 2+ minutes)"
        fi
    elif container_exists "$CONTAINER_NAME"; then
        print_color "$YELLOW" "⚠ Dremio container exists but is not running"
        print_color "$BLUE" "Run: $0 start"
    else
        print_color "$RED" "✗ Dremio container does not exist"
        print_color "$BLUE" "Run: $0 start"
    fi
}

case "${1:-start}" in
    start) start_dremio ;;
    stop) stop_dremio ;;
    restart) stop_dremio && start_dremio ;;
    status) status_dremio ;;
    logs) logs_dremio "$2" ;;
    *) echo "Usage: $0 {start|stop|restart|status|logs}" ;;
esac