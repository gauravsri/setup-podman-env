#!/bin/bash
# Common utilities for all pod scripts

# Load environment configuration
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
ENV_FILE="$SCRIPT_DIR/.env"

# Check if configuration is already provided via environment variables (from project wrapper)
if [[ -n "$PROJECT_NAME" ]]; then
    # Configuration is already loaded by project wrapper - use it directly
    :  # no-op, just use existing environment variables
elif [[ -f "$ENV_FILE" ]]; then
    # Load .env file, ignoring comments and empty lines
    set -a  # automatically export all variables
    source <(grep -v '^#' "$ENV_FILE" | grep -v '^$')
    set +a  # stop automatically exporting
else
    echo "⚠️ Warning: .env file not found at $ENV_FILE"
    echo "Using fallback configuration..."
    # Fallback configuration
    PROJECT_NAME="spark-e2e"
    NETWORK_NAME="${PROJECT_NAME}-network"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_color() {
    echo -e "${1}${2}${NC}"
}

print_header() {
    echo
    print_color "$BLUE" "=============================================="
    print_color "$BLUE" "$1"
    print_color "$BLUE" "=============================================="
}

ensure_network() {
    if ! podman network exists "$NETWORK_NAME" 2>/dev/null; then
        print_color "$YELLOW" "Creating network: $NETWORK_NAME"
        podman network create "$NETWORK_NAME" >/dev/null
        print_color "$GREEN" "✓ Network created"
    fi
}

# Windows path conversion for volume mounts
get_host_path() {
    local path="$1"
    echo "$(pwd | sed 's|^/c/|C:/|')/$path"
}

wait_for_service() {
    local service_name="$1"
    local url="$2"
    local max_wait="${3:-60}"
    local wait_time=0

    print_color "$YELLOW" "Waiting for $service_name to be ready..."
    while [[ $wait_time -lt $max_wait ]]; do
        if curl -sf "$url" >/dev/null 2>&1; then
            print_color "$GREEN" "✓ $service_name is ready"
            return 0
        fi
        sleep 2
        wait_time=$((wait_time + 2))
    done
    print_color "$YELLOW" "⚠ $service_name may still be starting up"
    return 1
}

container_exists() {
    local container_name="$1"
    podman ps -a --filter "name=$container_name" --format "{{.Names}}" | grep -q "^$container_name$"
}

container_running() {
    local container_name="$1"
    podman ps --filter "name=$container_name" --format "{{.Names}}" | grep -q "^$container_name$"
}

start_existing_container() {
    local container_name="$1"
    if container_exists "$container_name"; then
        if ! container_running "$container_name"; then
            print_color "$YELLOW" "Starting existing $container_name..."
            podman start "$container_name" >/dev/null
            print_color "$GREEN" "✓ $container_name started"
        else
            print_color "$GREEN" "✓ $container_name already running"
        fi
        return 0
    fi
    return 1
}

stop_container() {
    local container_name="$1"
    if container_running "$container_name"; then
        print_color "$YELLOW" "Stopping $container_name..."
        podman stop "$container_name" >/dev/null
        print_color "$GREEN" "✓ $container_name stopped"
    else
        print_color "$BLUE" "$container_name not running"
    fi
}

get_container_logs() {
    local container_name="$1"
    local lines="${2:-20}"
    if container_exists "$container_name"; then
        print_color "$BLUE" "📋 Last $lines log lines from $container_name:"
        podman logs "$container_name" --tail "$lines"
    else
        print_color "$RED" "Container $container_name does not exist"
    fi
}