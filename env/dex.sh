#!/bin/bash
# Dex (OIDC Identity Provider) Pod Management
# Provides OpenID Connect and OAuth2 authentication services

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Source common functions
source "$SCRIPT_DIR/common.sh"

# Dex configuration
CONTAINER_NAME="${DEX_CONTAINER_NAME:-dex}"
IMAGE="${DEX_IMAGE:-ghcr.io/dexidp/dex:latest}"
HTTP_PORT="${DEX_HTTP_PORT:-5556}"
GRPC_PORT="${DEX_GRPC_PORT:-5557}"
MEMORY="${DEX_MEMORY:-256m}"
VOLUME_NAME="${DEX_VOLUME_NAME:-dex-data}"
ISSUER="${DEX_ISSUER:-http://localhost:5556/dex}"

create_dex_config() {
    local config_file="/tmp/dex-config.yaml"
    cat > "$config_file" << EOF
issuer: $ISSUER

storage:
  type: memory

web:
  http: 0.0.0.0:5556

staticClients:
- id: example-app
  redirectURIs:
  - 'http://localhost:5555/auth/callback'
  name: 'Example App'
  secret: ZXhhbXBsZS1hcHAtc2VjcmV0

connectors:
- type: mockCallback
  id: mock
  name: Example
  config:
    username: "admin@example.com"
    groups: ["admins", "users"]

enablePasswordDB: true

staticPasswords:
- email: "admin@example.com"
  hash: "\$2a\$10\$2b2cU8CPhOTaGrs1HRQuAueS7JTT5ZHsHSzYiFPm1leZck7Mc8T4W"
  username: "admin"
  userID: "08a8684b-db88-4b73-90a9-3cd1661f5466"
- email: "user@example.com"
  hash: "\$2a\$10\$2b2cU8CPhOTaGrs1HRQuAueS7JTT5ZHsHSzYiFPm1leZck7Mc8T4W"
  username: "user"
  userID: "41331323-6f44-45e6-b3b9-2c4b60c02be5"

expiry:
  deviceRequests: "5m"
  signingKeys: "6h"
  idTokens: "24h"
  refreshTokens:
    reuseInterval: "3s"
    validIfNotUsedFor: "2160h" # 90 days
    absoluteLifetime: "3960h" # 165 days
EOF
    echo "$config_file"
}

start_dex() {
    print_header "🔐 STARTING DEX"

    ensure_network

    if container_exists "$CONTAINER_NAME"; then
        print_warning "Dex container already exists. Use restart to recreate."
        return 0
    fi

    print_info "Creating Dex volume..."
    create_volume "$VOLUME_NAME"

    print_info "Creating Dex configuration..."
    local config_file=$(create_dex_config)

    print_info "Starting Dex container..."
    podman run -d \
        --name "$CONTAINER_NAME" \
        --network "$NETWORK_NAME" \
        -p "$HTTP_PORT:5556" \
        -p "$GRPC_PORT:5557" \
        -v "$config_file:/etc/dex/config.yaml:ro" \
        -v "$VOLUME_NAME:/var/dex" \
        --memory="$MEMORY" \
        "$IMAGE" \
        dex serve /etc/dex/config.yaml

    wait_for_service "Dex" "$HTTP_PORT" "/dex/.well-known/openid_configuration"

    if [ $? -eq 0 ]; then
        print_success "Dex started successfully!"
        print_info "OIDC Issuer: $ISSUER"
        print_info "Web UI: http://localhost:$HTTP_PORT/dex/auth"
        print_info "Well-known: http://localhost:$HTTP_PORT/dex/.well-known/openid_configuration"
        print_info "Credentials: admin@example.com/password or user@example.com/password"
    else
        print_error "Dex failed to start properly"
        return 1
    fi
}

stop_dex() {
    print_header "🔐 STOPPING DEX"

    if container_exists "$CONTAINER_NAME"; then
        print_info "Stopping Dex container..."
        podman stop "$CONTAINER_NAME"
        podman rm "$CONTAINER_NAME"

        # Clean up config file
        rm -f /tmp/dex-config.yaml

        print_success "Dex stopped and removed"
    else
        print_warning "Dex container not found"
    fi
}

restart_dex() {
    print_header "🔐 RESTARTING DEX"
    stop_dex
    sleep 2
    start_dex
}

show_dex_logs() {
    local lines="${1:-50}"

    if container_exists "$CONTAINER_NAME"; then
        print_header "🔐 DEX LOGS (last $lines lines)"
        podman logs --tail "$lines" -f "$CONTAINER_NAME"
    else
        print_error "Dex container not found"
        return 1
    fi
}

show_dex_status() {
    print_header "🔐 DEX STATUS"

    if container_exists "$CONTAINER_NAME"; then
        local status=$(podman ps --filter "name=$CONTAINER_NAME" --format "{{.Status}}")
        if [[ -n "$status" ]]; then
            print_success "Dex is running ($status)"
            print_info "OIDC Issuer: $ISSUER"
            print_info "HTTP Port: $HTTP_PORT"
            print_info "gRPC Port: $GRPC_PORT"

            # Check health
            if curl -sf "http://localhost:$HTTP_PORT/dex/.well-known/openid_configuration" >/dev/null 2>&1; then
                print_success "✅ Dex OIDC endpoint is responding"
            else
                print_warning "⚠️ Dex OIDC endpoint not responding"
            fi
        else
            print_warning "Dex container exists but is not running"
        fi
    else
        print_info "Dex container not found"
    fi
}

test_dex() {
    print_header "🔐 TESTING DEX"

    if ! container_exists "$CONTAINER_NAME"; then
        print_error "Dex container not running"
        return 1
    fi

    print_info "Fetching OIDC configuration..."
    if curl -s "http://localhost:$HTTP_PORT/dex/.well-known/openid_configuration" | jq . 2>/dev/null; then
        print_success "OIDC configuration retrieved successfully"
    else
        print_error "Failed to retrieve OIDC configuration"
        return 1
    fi
}

usage() {
    echo "Usage: $0 {start|stop|restart|logs|status|test}"
    echo
    echo "Commands:"
    echo "  start   - Start Dex container"
    echo "  stop    - Stop and remove Dex container"
    echo "  restart - Stop and start Dex container"
    echo "  logs    - Show Dex logs"
    echo "  status  - Show Dex status"
    echo "  test    - Test OIDC configuration"
    echo
    echo "Configuration:"
    echo "  Container: $CONTAINER_NAME"
    echo "  Image: $IMAGE"
    echo "  HTTP Port: $HTTP_PORT"
    echo "  gRPC Port: $GRPC_PORT"
    echo "  Issuer: $ISSUER"
    echo "  Memory: $MEMORY"
    echo
    echo "Test Users:"
    echo "  admin@example.com / password (admin group)"
    echo "  user@example.com / password (user group)"
    echo
    echo "Example Client:"
    echo "  ID: example-app"
    echo "  Secret: ZXhhbXBsZS1hcHAtc2VjcmV0"
    echo "  Redirect: http://localhost:5555/auth/callback"
}

main() {
    case "${1:-status}" in
        start)
            start_dex
            ;;
        stop)
            stop_dex
            ;;
        restart)
            restart_dex
            ;;
        logs)
            show_dex_logs "${2:-50}"
            ;;
        status)
            show_dex_status
            ;;
        test)
            test_dex
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