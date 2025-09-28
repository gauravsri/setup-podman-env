#!/bin/bash
# ZincSearch (Lightweight Search Engine) Pod Management
# Provides full-text search capabilities with REST API

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Source common functions
source "$SCRIPT_DIR/common.sh"

# ZincSearch configuration
CONTAINER_NAME="${ZINCSEARCH_CONTAINER_NAME:-zincsearch}"
IMAGE="${ZINCSEARCH_IMAGE:-public.ecr.aws/zinclabs/zincsearch:latest}"
HTTP_PORT="${ZINCSEARCH_HTTP_PORT:-4080}"
MEMORY="${ZINCSEARCH_MEMORY:-512m}"
VOLUME_NAME="${ZINCSEARCH_VOLUME_NAME:-zincsearch-data}"
ADMIN_USER="${ZINCSEARCH_ADMIN_USER:-admin}"
ADMIN_PASSWORD="${ZINCSEARCH_ADMIN_PASSWORD:-admin}"

start_zincsearch() {
    print_header "🔍 STARTING ZINCSEARCH"

    ensure_network

    if container_exists "$CONTAINER_NAME"; then
        print_warning "ZincSearch container already exists. Use restart to recreate."
        return 0
    fi

    print_info "Creating ZincSearch volume..."
    create_volume "$VOLUME_NAME"

    print_info "Starting ZincSearch container..."
    podman run -d \
        --name "$CONTAINER_NAME" \
        --network "$NETWORK_NAME" \
        -p "$HTTP_PORT:4080" \
        -v "$VOLUME_NAME:/data" \
        -e ZINC_DATA_PATH="/data" \
        -e ZINC_FIRST_ADMIN_USER="$ADMIN_USER" \
        -e ZINC_FIRST_ADMIN_PASSWORD="$ADMIN_PASSWORD" \
        --memory="$MEMORY" \
        "$IMAGE"

    wait_for_service "ZincSearch" "$HTTP_PORT" "/api/index"

    if [ $? -eq 0 ]; then
        print_success "ZincSearch started successfully!"
        print_info "Web UI: http://localhost:$HTTP_PORT"
        print_info "Credentials: $ADMIN_USER/$ADMIN_PASSWORD"
        print_info "API Docs: http://localhost:$HTTP_PORT/ui/"
    else
        print_error "ZincSearch failed to start properly"
        return 1
    fi
}

stop_zincsearch() {
    print_header "🔍 STOPPING ZINCSEARCH"

    if container_exists "$CONTAINER_NAME"; then
        print_info "Stopping ZincSearch container..."
        podman stop "$CONTAINER_NAME"
        podman rm "$CONTAINER_NAME"
        print_success "ZincSearch stopped and removed"
    else
        print_warning "ZincSearch container not found"
    fi
}

restart_zincsearch() {
    print_header "🔍 RESTARTING ZINCSEARCH"
    stop_zincsearch
    sleep 2
    start_zincsearch
}

show_zincsearch_logs() {
    local lines="${1:-50}"

    if container_exists "$CONTAINER_NAME"; then
        print_header "🔍 ZINCSEARCH LOGS (last $lines lines)"
        podman logs --tail "$lines" -f "$CONTAINER_NAME"
    else
        print_error "ZincSearch container not found"
        return 1
    fi
}

show_zincsearch_status() {
    print_header "🔍 ZINCSEARCH STATUS"

    if container_exists "$CONTAINER_NAME"; then
        local status=$(podman ps --filter "name=$CONTAINER_NAME" --format "{{.Status}}")
        if [[ -n "$status" ]]; then
            print_success "ZincSearch is running ($status)"
            print_info "Web UI: http://localhost:$HTTP_PORT"
            print_info "API: http://localhost:$HTTP_PORT/api"

            # Check health
            if curl -sf "http://localhost:$HTTP_PORT/api/index" >/dev/null 2>&1; then
                print_success "✅ ZincSearch API is responding"
            else
                print_warning "⚠️ ZincSearch API not responding"
            fi
        else
            print_warning "ZincSearch container exists but is not running"
        fi
    else
        print_info "ZincSearch container not found"
    fi
}

usage() {
    echo "Usage: $0 {start|stop|restart|logs|status}"
    echo
    echo "Commands:"
    echo "  start   - Start ZincSearch container"
    echo "  stop    - Stop and remove ZincSearch container"
    echo "  restart - Stop and start ZincSearch container"
    echo "  logs    - Show ZincSearch logs"
    echo "  status  - Show ZincSearch status"
    echo
    echo "Configuration:"
    echo "  Container: $CONTAINER_NAME"
    echo "  Image: $IMAGE"
    echo "  HTTP Port: $HTTP_PORT"
    echo "  Memory: $MEMORY"
    echo "  Admin User: $ADMIN_USER"
}

main() {
    case "${1:-status}" in
        start)
            start_zincsearch
            ;;
        stop)
            stop_zincsearch
            ;;
        restart)
            restart_zincsearch
            ;;
        logs)
            show_zincsearch_logs "${2:-50}"
            ;;
        status)
            show_zincsearch_status
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