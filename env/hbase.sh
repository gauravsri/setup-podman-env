#!/bin/bash
# HBase (NoSQL Database) Pod Management
# Provides standalone HBase instance for testing

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Source common functions
source "$SCRIPT_DIR/common.sh"

# HBase configuration
CONTAINER_NAME="${HBASE_CONTAINER_NAME:-hbase-standalone}"
IMAGE="${HBASE_IMAGE:-harisekhon/hbase:latest}"
MASTER_PORT="${HBASE_MASTER_PORT:-16000}"
MASTER_WEB_PORT="${HBASE_MASTER_WEB_PORT:-16010}"
REGION_PORT="${HBASE_REGION_PORT:-16020}"
REGION_WEB_PORT="${HBASE_REGION_WEB_PORT:-16030}"
ZOOKEEPER_PORT="${HBASE_ZOOKEEPER_PORT:-2181}"
VOLUME_NAME="${HBASE_VOLUME_NAME:-hbase-data}"

start_hbase() {
    print_header "🗄️  STARTING HBASE"

    ensure_network

    if container_exists "$CONTAINER_NAME"; then
        print_warning "HBase already exists. Use restart to recreate."
        return 0
    fi

    print_info "Creating HBase volume..."
    create_volume "$VOLUME_NAME"

    # Start HBase in standalone mode
    print_info "Starting HBase standalone..."
    podman run -d \
        --name "$CONTAINER_NAME" \
        --network "$NETWORK_NAME" \
        --hostname hbase-standalone \
        -p "$ZOOKEEPER_PORT:2181" \
        -p "$MASTER_PORT:16000" \
        -p "$MASTER_WEB_PORT:16010" \
        -p "$REGION_PORT:16020" \
        -p "$REGION_WEB_PORT:16030" \
        -v "$VOLUME_NAME:/hbase-data" \
        "$IMAGE"

    # Wait for HBase to be ready
    print_info "Waiting for HBase to be ready..."
    for i in {1..60}; do
        if curl -sf "http://localhost:$MASTER_WEB_PORT" >/dev/null 2>&1; then
            print_success "HBase started successfully!"
            break
        fi
        sleep 2
    done

    print_success "HBase cluster started!"
    print_info "Master Web UI: http://localhost:$MASTER_WEB_PORT"
    print_info "Zookeeper: localhost:$ZOOKEEPER_PORT"
}

stop_hbase() {
    print_header "🗄️  STOPPING HBASE"

    if container_exists "$CONTAINER_NAME"; then
        print_info "Stopping HBase..."
        podman stop "$CONTAINER_NAME"
        podman rm "$CONTAINER_NAME"
        print_success "HBase stopped and removed"
    else
        print_warning "HBase container not found"
    fi
}

restart_hbase() {
    print_header "🗄️  RESTARTING HBASE"
    stop_hbase
    sleep 3
    start_hbase
}

show_hbase_logs() {
    local lines="${1:-50}"

    if container_exists "$CONTAINER_NAME"; then
        print_header "🗄️  HBASE LOGS (last $lines lines)"
        podman logs --tail "$lines" -f "$CONTAINER_NAME"
    else
        print_error "HBase container not found"
        return 1
    fi
}

show_hbase_status() {
    print_header "🗄️  HBASE STATUS"

    if container_exists "$CONTAINER_NAME"; then
        local status=$(podman ps --filter "name=$CONTAINER_NAME" --format "{{.Status}}")
        if [[ -n "$status" ]]; then
            print_success "HBase is running ($status)"
            print_info "Master Web UI: http://localhost:$MASTER_WEB_PORT"
            print_info "Zookeeper: localhost:$ZOOKEEPER_PORT"

            # Check web UI health
            if curl -sf "http://localhost:$MASTER_WEB_PORT" >/dev/null 2>&1; then
                print_success "Master web UI is responding"
            else
                print_warning "Master web UI not responding"
            fi
        else
            print_warning "HBase container exists but is not running"
        fi
    else
        print_info "HBase container not found"
    fi
}

hbase_shell() {
    print_header "🗄️  HBASE SHELL"

    if ! container_exists "$CONTAINER_NAME"; then
        print_error "HBase not running"
        return 1
    fi

    print_info "Connecting to HBase shell..."
    podman exec -it "$CONTAINER_NAME" hbase shell
}

create_test_data() {
    print_header "🗄️  CREATING TEST DATA"

    if ! container_exists "$CONTAINER_NAME"; then
        print_error "HBase not running"
        return 1
    fi

    print_info "Creating test table and data..."

    podman exec "$CONTAINER_NAME" bash -c "hbase shell <<'EOF'
create 'user_table', 'cf1'
put 'user_table', 'user_001', 'cf1:email', 'user001@example.com'
put 'user_table', 'user_001', 'cf1:name', 'John Doe'
put 'user_table', 'user_001', 'cf1:age', '30'
put 'user_table', 'user_002', 'cf1:email', 'user002@example.com'
put 'user_table', 'user_002', 'cf1:name', 'Jane Smith'
put 'user_table', 'user_002', 'cf1:age', '28'
put 'user_table', 'user_003', 'cf1:email', 'user003@example.com'
put 'user_table', 'user_003', 'cf1:name', 'Bob Johnson'
put 'user_table', 'user_003', 'cf1:age', '35'
put 'user_table', 'user_004', 'cf1:email', 'user004@example.com'
put 'user_table', 'user_004', 'cf1:name', 'Alice Brown'
put 'user_table', 'user_004', 'cf1:age', '32'
put 'user_table', 'user_005', 'cf1:email', 'user005@example.com'
put 'user_table', 'user_005', 'cf1:name', 'Charlie Wilson'
put 'user_table', 'user_005', 'cf1:age', '27'
scan 'user_table'
count 'user_table'
EOF"

    print_success "Test data created in 'user_table'"
}

create_snapshot() {
    print_header "🗄️  CREATING SNAPSHOT"

    if ! container_exists "$CONTAINER_NAME"; then
        print_error "HBase not running"
        return 1
    fi

    local snapshot_name="${1:-user_table_snapshot}"

    print_info "Creating snapshot: $snapshot_name"

    podman exec "$CONTAINER_NAME" bash -c "hbase shell <<EOF
snapshot 'user_table', '$snapshot_name'
list_snapshots
EOF"

    print_success "Snapshot '$snapshot_name' created"
}

usage() {
    echo "Usage: $0 {start|stop|restart|logs|status|shell|create-test-data|create-snapshot}"
    echo
    echo "Commands:"
    echo "  start              - Start HBase standalone"
    echo "  stop               - Stop and remove HBase"
    echo "  restart            - Stop and start HBase"
    echo "  logs               - Show logs [lines]"
    echo "  status             - Show HBase status"
    echo "  shell              - Open HBase shell"
    echo "  create-test-data   - Create test table with sample data"
    echo "  create-snapshot    - Create snapshot [name]"
    echo
    echo "Configuration:"
    echo "  Container: $CONTAINER_NAME"
    echo "  Image: $IMAGE"
    echo "  Master Web UI: $MASTER_WEB_PORT"
    echo "  Zookeeper: $ZOOKEEPER_PORT"
}

main() {
    case "${1:-status}" in
        start)
            start_hbase
            ;;
        stop)
            stop_hbase
            ;;
        restart)
            restart_hbase
            ;;
        logs)
            show_hbase_logs "${2:-50}"
            ;;
        status)
            show_hbase_status
            ;;
        shell)
            hbase_shell
            ;;
        create-test-data)
            create_test_data
            ;;
        create-snapshot)
            create_snapshot "${2:-user_table_snapshot}"
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
