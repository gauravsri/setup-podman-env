#!/bin/bash
# Apache Spark (Distributed Computing) Pod Management
# Provides Spark master with configurable number of workers

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Source common functions
source "$SCRIPT_DIR/common.sh"

# Spark configuration
MASTER_CONTAINER_NAME="${SPARK_MASTER_CONTAINER_NAME:-spark-master}"
WORKER_CONTAINER_PREFIX="${SPARK_WORKER_CONTAINER_PREFIX:-spark-worker}"
IMAGE="${SPARK_IMAGE:-apache/spark:latest}"
MASTER_PORT="${SPARK_MASTER_PORT:-7077}"
MASTER_WEB_PORT="${SPARK_MASTER_WEB_PORT:-8070}"
WORKER_WEB_PORT_BASE="${SPARK_WORKER_WEB_PORT_BASE:-8200}"
MEMORY="${SPARK_MEMORY:-1g}"
WORKER_MEMORY="${SPARK_WORKER_MEMORY:-1g}"
WORKER_CORES="${SPARK_WORKER_CORES:-1}"
WORKER_COUNT="${SPARK_WORKER_COUNT:-1}"
VOLUME_NAME="${SPARK_VOLUME_NAME:-spark-data}"

start_spark() {
    print_header "⚡ STARTING APACHE SPARK"

    ensure_network

    if container_exists "$MASTER_CONTAINER_NAME"; then
        print_warning "Spark master already exists. Use restart to recreate."
        return 0
    fi

    print_info "Creating Spark volume..."
    create_volume "$VOLUME_NAME"

    # Start Spark Master
    print_info "Starting Spark Master..."
    podman run -d \
        --name "$MASTER_CONTAINER_NAME" \
        --network "$NETWORK_NAME" \
        --hostname spark-master \
        -p "$MASTER_PORT:7077" \
        -p "$MASTER_WEB_PORT:8080" \
        -v "$VOLUME_NAME:/opt/bitnami/spark/work-dir" \
        -e SPARK_MODE=master \
        --memory="$MEMORY" \
        "$IMAGE"

    # Wait for master to be ready
    print_info "Waiting for Spark Master to be ready..."
    for i in {1..30}; do
        if curl -sf "http://localhost:$MASTER_WEB_PORT" >/dev/null 2>&1; then
            print_success "Spark Master started successfully!"
            break
        fi
        sleep 2
    done

    # Start Spark Workers
    for ((i=1; i<=WORKER_COUNT; i++)); do
        local worker_name="${WORKER_CONTAINER_PREFIX}-${i}"
        local worker_web_port=$((WORKER_WEB_PORT_BASE + i - 1))

        print_info "Starting Spark Worker $i..."
        podman run -d \
            --name "$worker_name" \
            --network "$NETWORK_NAME" \
            --hostname "$worker_name" \
            -p "$worker_web_port:8081" \
            -v "$VOLUME_NAME:/opt/bitnami/spark/work-dir" \
            -e SPARK_MODE=worker \
            -e SPARK_MASTER_URL=spark://spark-master:7077 \
            -e SPARK_WORKER_CORES="$WORKER_CORES" \
            -e SPARK_WORKER_MEMORY="$WORKER_MEMORY" \
            --memory="$WORKER_MEMORY" \
            "$IMAGE"
    done

    # Wait a bit for workers to register
    sleep 5

    print_success "Spark cluster started successfully!"
    print_info "Master UI: http://localhost:$MASTER_WEB_PORT"
    print_info "Master URL: spark://localhost:$MASTER_PORT"
    for ((i=1; i<=WORKER_COUNT; i++)); do
        local worker_web_port=$((WORKER_WEB_PORT_BASE + i - 1))
        print_info "Worker $i UI: http://localhost:$worker_web_port"
    done
}

stop_spark() {
    print_header "⚡ STOPPING APACHE SPARK"

    # Stop workers first
    for ((i=1; i<=WORKER_COUNT; i++)); do
        local worker_name="${WORKER_CONTAINER_PREFIX}-${i}"
        if container_exists "$worker_name"; then
            print_info "Stopping Spark Worker $i..."
            podman stop "$worker_name"
            podman rm "$worker_name"
        fi
    done

    # Stop master
    if container_exists "$MASTER_CONTAINER_NAME"; then
        print_info "Stopping Spark Master..."
        podman stop "$MASTER_CONTAINER_NAME"
        podman rm "$MASTER_CONTAINER_NAME"
        print_success "Spark cluster stopped and removed"
    else
        print_warning "Spark master container not found"
    fi
}

restart_spark() {
    print_header "⚡ RESTARTING APACHE SPARK"
    stop_spark
    sleep 3
    start_spark
}

show_spark_logs() {
    local component="${1:-master}"
    local lines="${2:-50}"

    case "$component" in
        master)
            if container_exists "$MASTER_CONTAINER_NAME"; then
                print_header "⚡ SPARK MASTER LOGS (last $lines lines)"
                podman logs --tail "$lines" -f "$MASTER_CONTAINER_NAME"
            else
                print_error "Spark master container not found"
                return 1
            fi
            ;;
        worker*)
            local worker_num="${component#worker}"
            if [[ -z "$worker_num" ]]; then
                worker_num="1"
            fi
            local worker_name="${WORKER_CONTAINER_PREFIX}-${worker_num}"
            if container_exists "$worker_name"; then
                print_header "⚡ SPARK WORKER $worker_num LOGS (last $lines lines)"
                podman logs --tail "$lines" -f "$worker_name"
            else
                print_error "Spark worker $worker_num container not found"
                return 1
            fi
            ;;
        *)
            print_error "Unknown component: $component. Use 'master', 'worker1', 'worker2', etc."
            return 1
            ;;
    esac
}

show_spark_status() {
    print_header "⚡ APACHE SPARK STATUS"

    # Check Master
    if container_exists "$MASTER_CONTAINER_NAME"; then
        local status=$(podman ps --filter "name=$MASTER_CONTAINER_NAME" --format "{{.Status}}")
        if [[ -n "$status" ]]; then
            print_success "Spark Master is running ($status)"
            print_info "Master UI: http://localhost:$MASTER_WEB_PORT"
            print_info "Master URL: spark://localhost:$MASTER_PORT"

            # Check master health
            if curl -sf "http://localhost:$MASTER_WEB_PORT" >/dev/null 2>&1; then
                print_success "✅ Master web UI is responding"
            else
                print_warning "⚠️ Master web UI not responding"
            fi
        else
            print_warning "Spark master container exists but is not running"
        fi
    else
        print_info "Spark master container not found"
    fi

    # Check Workers
    local running_workers=0
    for ((i=1; i<=WORKER_COUNT; i++)); do
        local worker_name="${WORKER_CONTAINER_PREFIX}-${i}"
        if container_exists "$worker_name"; then
            local status=$(podman ps --filter "name=$worker_name" --format "{{.Status}}")
            if [[ -n "$status" ]]; then
                local worker_web_port=$((WORKER_WEB_PORT_BASE + i - 1))
                print_success "Worker $i is running ($status)"
                print_info "  Worker $i UI: http://localhost:$worker_web_port"
                running_workers=$((running_workers + 1))
            else
                print_warning "Worker $i container exists but is not running"
            fi
        fi
    done

    if [[ $running_workers -eq 0 ]]; then
        print_info "No Spark workers running"
    else
        print_info "Total running workers: $running_workers/$WORKER_COUNT"
    fi
}

submit_example() {
    print_header "⚡ SUBMITTING EXAMPLE SPARK JOB"

    if ! container_exists "$MASTER_CONTAINER_NAME"; then
        print_error "Spark master not running"
        return 1
    fi

    print_info "Submitting SparkPi example..."
    podman exec "$MASTER_CONTAINER_NAME" \
        /opt/spark/bin/spark-submit \
        --master spark://spark-master:7077 \
        --class org.apache.spark.examples.SparkPi \
        /opt/spark/examples/jars/spark-examples_*.jar \
        10

    print_info "Check the Spark Master UI for job details: http://localhost:$MASTER_WEB_PORT"
}

usage() {
    echo "Usage: $0 {start|stop|restart|logs|status|submit-example}"
    echo
    echo "Commands:"
    echo "  start         - Start Spark cluster (master + $WORKER_COUNT workers)"
    echo "  stop          - Stop and remove Spark cluster"
    echo "  restart       - Stop and start Spark cluster"
    echo "  logs          - Show logs [master|worker1|worker2] [lines]"
    echo "  status        - Show Spark cluster status"
    echo "  submit-example - Submit SparkPi example job"
    echo
    echo "Configuration:"
    echo "  Master: $MASTER_CONTAINER_NAME"
    echo "  Workers: $WORKER_COUNT x ${WORKER_CONTAINER_PREFIX}-N"
    echo "  Image: $IMAGE"
    echo "  Master Port: $MASTER_PORT"
    echo "  Master Web UI: $MASTER_WEB_PORT"
    echo "  Worker Memory: $WORKER_MEMORY"
    echo "  Worker Cores: $WORKER_CORES"
    echo
    echo "Usage Examples:"
    echo "  # Submit a Spark job"
    echo "  podman exec $MASTER_CONTAINER_NAME \\"
    echo "    /opt/spark/bin/spark-submit \\"
    echo "    --master spark://spark-master:7077 \\"
    echo "    --class MyApp my-app.jar"
}

main() {
    case "${1:-status}" in
        start)
            start_spark
            ;;
        stop)
            stop_spark
            ;;
        restart)
            restart_spark
            ;;
        logs)
            show_spark_logs "${2:-master}" "${3:-50}"
            ;;
        status)
            show_spark_status
            ;;
        submit-example)
            submit_example
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