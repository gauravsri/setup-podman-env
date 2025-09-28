#!/bin/bash
# Redpanda (Kafka-Compatible Streaming Platform) Pod Management
# Provides streaming data platform with Kafka API compatibility

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Source common functions
source "$SCRIPT_DIR/common.sh"

# Redpanda configuration
CONTAINER_NAME="${REDPANDA_CONTAINER_NAME:-redpanda}"
IMAGE="${REDPANDA_IMAGE:-docker.redpanda.com/redpandadata/redpanda:latest}"
KAFKA_PORT="${REDPANDA_KAFKA_PORT:-9092}"
ADMIN_PORT="${REDPANDA_ADMIN_PORT:-9644}"
PANDAPROXY_PORT="${REDPANDA_PANDAPROXY_PORT:-8100}"
SCHEMA_REGISTRY_PORT="${REDPANDA_SCHEMA_REGISTRY_PORT:-8101}"
MEMORY="${REDPANDA_MEMORY:-1g}"
VOLUME_NAME="${REDPANDA_VOLUME_NAME:-redpanda-data}"

start_redpanda() {
    print_header "🐼 STARTING REDPANDA"

    ensure_network

    if container_exists "$CONTAINER_NAME"; then
        print_warning "Redpanda container already exists. Use restart to recreate."
        return 0
    fi

    print_info "Creating Redpanda volume..."
    create_volume "$VOLUME_NAME"

    print_info "Starting Redpanda container..."
    podman run -d \
        --name "$CONTAINER_NAME" \
        --network "$NETWORK_NAME" \
        -p "$KAFKA_PORT:9092" \
        -p "$ADMIN_PORT:9644" \
        -p "$PANDAPROXY_PORT:8082" \
        -p "$SCHEMA_REGISTRY_PORT:8081" \
        -v "$VOLUME_NAME:/var/lib/redpanda/data" \
        --memory="$MEMORY" \
        "$IMAGE" \
        redpanda start \
        --mode dev-container \
        --kafka-addr PLAINTEXT://0.0.0.0:29092,OUTSIDE://0.0.0.0:9092 \
        --advertise-kafka-addr PLAINTEXT://redpanda:29092,OUTSIDE://localhost:9092 \
        --pandaproxy-addr 0.0.0.0:8082 \
        --advertise-pandaproxy-addr localhost:8082 \
        --schema-registry-addr 0.0.0.0:8081 \
        --rpc-addr 0.0.0.0:33145 \
        --advertise-rpc-addr redpanda:33145 \
        --smp 1 \
        --memory 1G \
        --reserve-memory 0M \
        --overprovisioned \
        --node-id 0 \
        --check=false

    # Wait for Redpanda to be ready
    print_info "Waiting for Redpanda to be ready..."
    for i in {1..60}; do
        if curl -sf "http://localhost:$ADMIN_PORT/v1/status/ready" >/dev/null 2>&1; then
            print_success "Redpanda started successfully!"
            print_info "Kafka API: localhost:$KAFKA_PORT"
            print_info "Admin API: http://localhost:$ADMIN_PORT"
            print_info "Pandaproxy (REST): http://localhost:$PANDAPROXY_PORT"
            print_info "Schema Registry: http://localhost:$SCHEMA_REGISTRY_PORT"
            return 0
        fi
        sleep 2
    done

    print_warning "Redpanda may still be starting up"
    print_info "Check logs with: $0 logs"
}

stop_redpanda() {
    print_header "🐼 STOPPING REDPANDA"

    if container_exists "$CONTAINER_NAME"; then
        print_info "Stopping Redpanda container..."
        podman stop "$CONTAINER_NAME"
        podman rm "$CONTAINER_NAME"
        print_success "Redpanda stopped and removed"
    else
        print_warning "Redpanda container not found"
    fi
}

restart_redpanda() {
    print_header "🐼 RESTARTING REDPANDA"
    stop_redpanda
    sleep 3
    start_redpanda
}

show_redpanda_logs() {
    local lines="${1:-50}"

    if container_exists "$CONTAINER_NAME"; then
        print_header "🐼 REDPANDA LOGS (last $lines lines)"
        podman logs --tail "$lines" -f "$CONTAINER_NAME"
    else
        print_error "Redpanda container not found"
        return 1
    fi
}

show_redpanda_status() {
    print_header "🐼 REDPANDA STATUS"

    if container_exists "$CONTAINER_NAME"; then
        local status=$(podman ps --filter "name=$CONTAINER_NAME" --format "{{.Status}}")
        if [[ -n "$status" ]]; then
            print_success "Redpanda is running ($status)"
            print_info "Kafka API: localhost:$KAFKA_PORT"
            print_info "Admin API: http://localhost:$ADMIN_PORT"
            print_info "REST Proxy: http://localhost:$PANDAPROXY_PORT"
            print_info "Schema Registry: http://localhost:$SCHEMA_REGISTRY_PORT"

            # Check health
            if curl -sf "http://localhost:$ADMIN_PORT/v1/status/ready" >/dev/null 2>&1; then
                print_success "✅ Redpanda is ready"
            else
                print_warning "⚠️ Redpanda not ready yet"
            fi
        else
            print_warning "Redpanda container exists but is not running"
        fi
    else
        print_info "Redpanda container not found"
    fi
}

usage() {
    echo "Usage: $0 {start|stop|restart|logs|status}"
    echo
    echo "Commands:"
    echo "  start   - Start Redpanda container"
    echo "  stop    - Stop and remove Redpanda container"
    echo "  restart - Stop and start Redpanda container"
    echo "  logs    - Show Redpanda logs"
    echo "  status  - Show Redpanda status"
    echo
    echo "Configuration:"
    echo "  Container: $CONTAINER_NAME"
    echo "  Image: $IMAGE"
    echo "  Kafka Port: $KAFKA_PORT"
    echo "  Admin Port: $ADMIN_PORT"
    echo "  Memory: $MEMORY"
    echo
    echo "Usage Examples:"
    echo "  # Connect with kafka-console-producer"
    echo "  kafka-console-producer --bootstrap-server localhost:$KAFKA_PORT --topic test"
    echo
    echo "  # List topics via REST API"
    echo "  curl http://localhost:$PANDAPROXY_PORT/topics"
}

main() {
    case "${1:-status}" in
        start)
            start_redpanda
            ;;
        stop)
            stop_redpanda
            ;;
        restart)
            restart_redpanda
            ;;
        logs)
            show_redpanda_logs "${2:-50}"
            ;;
        status)
            show_redpanda_status
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            echo "❌ Unknown command: $1"
            usage
            exit 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi