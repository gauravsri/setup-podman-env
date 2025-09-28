#!/bin/bash
# Postfix (Email Server) Pod Management
# Provides SMTP email relay capabilities for applications

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Source common functions
source "$SCRIPT_DIR/common.sh"

# Postfix configuration
CONTAINER_NAME="${POSTFIX_CONTAINER_NAME:-postfix}"
IMAGE="${POSTFIX_IMAGE:-catatnight/postfix:latest}"
SMTP_PORT="${POSTFIX_SMTP_PORT:-1587}"
MEMORY="${POSTFIX_MEMORY:-256m}"
VOLUME_NAME="${POSTFIX_VOLUME_NAME:-postfix-data}"
HOSTNAME="${POSTFIX_HOSTNAME:-mail.example.com}"
DOMAIN="${POSTFIX_DOMAIN:-example.com}"
RELAY_HOST="${POSTFIX_RELAY_HOST:-}"
RELAY_PORT="${POSTFIX_RELAY_PORT:-587}"
RELAY_USER="${POSTFIX_RELAY_USER:-}"
RELAY_PASS="${POSTFIX_RELAY_PASS:-}"

start_postfix() {
    print_header "📧 STARTING POSTFIX"

    ensure_network

    if container_exists "$CONTAINER_NAME"; then
        print_warning "Postfix container already exists. Use restart to recreate."
        return 0
    fi

    print_info "Creating Postfix volume..."
    create_volume "$VOLUME_NAME"

    # Build environment variables
    local env_vars=""
    env_vars="$env_vars -e maildomain=$DOMAIN"
    env_vars="$env_vars -e smtp_user=noreply@$DOMAIN:password"

    if [[ -n "$RELAY_HOST" ]]; then
        env_vars="$env_vars -e relayhost=[$RELAY_HOST]:$RELAY_PORT"
        if [[ -n "$RELAY_USER" && -n "$RELAY_PASS" ]]; then
            env_vars="$env_vars -e smtp_sasl_auth_enable=yes"
            env_vars="$env_vars -e smtp_sasl_password_maps=hash:/etc/postfix/sasl_passwd"
            env_vars="$env_vars -e smtp_sasl_security_options=noanonymous"
            env_vars="$env_vars -e smtp_tls_security_level=encrypt"
            env_vars="$env_vars -e RELAY_USER=$RELAY_USER"
            env_vars="$env_vars -e RELAY_PASS=$RELAY_PASS"
        fi
    fi

    print_info "Starting Postfix container..."
    podman run -d \
        --name "$CONTAINER_NAME" \
        --network "$NETWORK_NAME" \
        --hostname "$HOSTNAME" \
        -p "$SMTP_PORT:25" \
        -v "$VOLUME_NAME:/var/spool/postfix" \
        $env_vars \
        --memory="$MEMORY" \
        "$IMAGE"

    # Wait for Postfix to be ready
    print_info "Waiting for Postfix to be ready..."
    for i in {1..30}; do
        if podman exec "$CONTAINER_NAME" postfix status >/dev/null 2>&1; then
            print_success "Postfix started successfully!"
            print_info "SMTP Server: localhost:$SMTP_PORT"
            print_info "Domain: $DOMAIN"
            if [[ -n "$RELAY_HOST" ]]; then
                print_info "Relay Host: $RELAY_HOST:$RELAY_PORT"
            fi
            return 0
        fi
        sleep 2
    done

    print_warning "Postfix may still be starting up"
    print_info "Check logs with: $0 logs"
}

stop_postfix() {
    print_header "📧 STOPPING POSTFIX"

    if container_exists "$CONTAINER_NAME"; then
        print_info "Stopping Postfix container..."
        podman stop "$CONTAINER_NAME"
        podman rm "$CONTAINER_NAME"
        print_success "Postfix stopped and removed"
    else
        print_warning "Postfix container not found"
    fi
}

restart_postfix() {
    print_header "📧 RESTARTING POSTFIX"
    stop_postfix
    sleep 2
    start_postfix
}

show_postfix_logs() {
    local lines="${1:-50}"

    if container_exists "$CONTAINER_NAME"; then
        print_header "📧 POSTFIX LOGS (last $lines lines)"
        podman logs --tail "$lines" -f "$CONTAINER_NAME"
    else
        print_error "Postfix container not found"
        return 1
    fi
}

show_postfix_status() {
    print_header "📧 POSTFIX STATUS"

    if container_exists "$CONTAINER_NAME"; then
        local status=$(podman ps --filter "name=$CONTAINER_NAME" --format "{{.Status}}")
        if [[ -n "$status" ]]; then
            print_success "Postfix is running ($status)"
            print_info "SMTP Server: localhost:$SMTP_PORT"
            print_info "Domain: $DOMAIN"
            print_info "Hostname: $HOSTNAME"

            # Check Postfix status inside container
            if podman exec "$CONTAINER_NAME" postfix status >/dev/null 2>&1; then
                print_success "✅ Postfix service is active"
            else
                print_warning "⚠️ Postfix service may not be ready"
            fi

            # Show queue status
            local queue_status=$(podman exec "$CONTAINER_NAME" postqueue -p 2>/dev/null | tail -1)
            if [[ "$queue_status" =~ "Mail queue is empty" ]]; then
                print_info "📬 Mail queue is empty"
            else
                print_info "📮 Mail queue has messages"
            fi
        else
            print_warning "Postfix container exists but is not running"
        fi
    else
        print_info "Postfix container not found"
    fi
}

test_postfix() {
    print_header "📧 TESTING POSTFIX"

    if ! container_exists "$CONTAINER_NAME"; then
        print_error "Postfix container not running"
        return 1
    fi

    print_info "Sending test email..."
    podman exec -i "$CONTAINER_NAME" bash -c "
        echo 'Subject: Test Email from Postfix
        From: test@$DOMAIN
        To: test@$DOMAIN

        This is a test email from Postfix container.
        ' | sendmail test@$DOMAIN
    "

    print_info "Test email queued. Check logs for delivery status."
}

usage() {
    echo "Usage: $0 {start|stop|restart|logs|status|test}"
    echo
    echo "Commands:"
    echo "  start   - Start Postfix container"
    echo "  stop    - Stop and remove Postfix container"
    echo "  restart - Stop and start Postfix container"
    echo "  logs    - Show Postfix logs"
    echo "  status  - Show Postfix status"
    echo "  test    - Send test email"
    echo
    echo "Configuration:"
    echo "  Container: $CONTAINER_NAME"
    echo "  Image: $IMAGE"
    echo "  SMTP Port: $SMTP_PORT"
    echo "  Domain: $DOMAIN"
    echo "  Memory: $MEMORY"
    echo
    echo "Usage Examples:"
    echo "  # Send email via SMTP"
    echo "  echo 'test email' | mail -s 'Subject' -S smtp=localhost:$SMTP_PORT recipient@example.com"
}

main() {
    case "${1:-status}" in
        start)
            start_postfix
            ;;
        stop)
            stop_postfix
            ;;
        restart)
            restart_postfix
            ;;
        logs)
            show_postfix_logs "${2:-50}"
            ;;
        status)
            show_postfix_status
            ;;
        test)
            test_postfix
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