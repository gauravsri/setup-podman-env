#!/bin/bash
# Project Wrapper Framework for setup-podman-env template
# Provides common functionality for project-specific setup scripts

# =============================================================================
# COMMON PROJECT WRAPPER FUNCTIONS
# =============================================================================

# Initialize project wrapper with configuration loading and validation
init_project_wrapper() {
    local script_dir="$1"
    local project_name="$2"

    # Set global variables
    SCRIPT_DIR="$script_dir"
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

    # Load project-specific configuration
    if [[ -f "$SCRIPT_DIR/.env" ]]; then
        set -a
        source <(grep -v '^#' "$SCRIPT_DIR/.env" | grep -v '^$')
        set +a
    else
        echo "❌ Project .env file not found at $SCRIPT_DIR/.env"
        echo "💡 Copy from template: cp ../setup-podman-env/env/.env.example .env"
        exit 1
    fi

    # Resolve template path
    if [[ "$TEMPLATE_PATH" =~ ^\.\./ ]]; then
        TEMPLATE_FULL_PATH="$(cd "$SCRIPT_DIR/$TEMPLATE_PATH" && pwd)"
    else
        TEMPLATE_FULL_PATH="$TEMPLATE_PATH"
    fi

    # Validate template exists
    if [[ ! -d "$TEMPLATE_FULL_PATH" ]]; then
        echo "❌ Template repository not found at: $TEMPLATE_FULL_PATH"
        echo "💡 Please ensure setup-podman-env is available at the specified path"
        echo "💡 Expected path in .env: TEMPLATE_PATH=\"$TEMPLATE_PATH\""
        exit 1
    fi

    # Validate template has required files (individual service scripts)
    if [[ ! -d "$TEMPLATE_FULL_PATH/env" ]]; then
        echo "❌ Invalid template: env/ directory not found in $TEMPLATE_FULL_PATH"
        exit 1
    fi

    # Set project name if provided
    if [[ -n "$project_name" ]]; then
        PROJECT_NAME="$project_name"
    fi

    # Export configuration for template
    export_project_config
}

# Export project configuration to environment for template consumption
export_project_config() {
    # Export all non-comment lines from .env
    export $(grep -v '^#' "$SCRIPT_DIR/.env" | grep -v '^$' | xargs)
}

# Parse and validate enabled services
parse_enabled_services() {
    if [[ -z "$ENABLED_SERVICES" ]]; then
        # Default to all services if not specified
        ENABLED_SERVICES="minio,dremio,airflow"
    fi

    # Convert comma-separated list to array
    IFS=',' read -ra ENABLED_SERVICES_ARRAY <<< "$ENABLED_SERVICES"

    # Validate that service scripts exist
    local missing_services=()
    for service in "${ENABLED_SERVICES_ARRAY[@]}"; do
        service=$(echo "$service" | xargs)  # trim whitespace
        if [[ ! -f "$TEMPLATE_FULL_PATH/env/$service.sh" ]]; then
            missing_services+=("$service")
        fi
    done

    if [[ ${#missing_services[@]} -gt 0 ]]; then
        print_error "Missing service scripts: ${missing_services[*]}"
        print_info "Available services:"
        ls "$TEMPLATE_FULL_PATH/env/"*.sh 2>/dev/null | xargs -n1 basename | sed 's/.sh$//' | sed 's/^/  - /' || echo "  - No service scripts found"
        exit 1
    fi
}

# Start enabled services
start_enabled_services() {
    local mode="$1"  # basic, full, or custom

    parse_enabled_services

    print_info "Starting services: ${ENABLED_SERVICES}"

    for service in "${ENABLED_SERVICES_ARRAY[@]}"; do
        service=$(echo "$service" | xargs)  # trim whitespace
        print_info "Starting $service..."
        if ! "$TEMPLATE_FULL_PATH/env/$service.sh" start; then
            print_error "Failed to start $service"
            return 1
        fi
    done
}

# Stop enabled services
stop_enabled_services() {
    parse_enabled_services

    print_info "Stopping services: ${ENABLED_SERVICES}"

    # Stop in reverse order
    for ((i=${#ENABLED_SERVICES_ARRAY[@]}-1; i>=0; i--)); do
        service=$(echo "${ENABLED_SERVICES_ARRAY[i]}" | xargs)  # trim whitespace
        print_info "Stopping $service..."
        "$TEMPLATE_FULL_PATH/env/$service.sh" stop
    done
}

# Show status of enabled services
show_enabled_services_status() {
    parse_enabled_services

    print_info "Service status for: ${ENABLED_SERVICES}"

    for service in "${ENABLED_SERVICES_ARRAY[@]}"; do
        service=$(echo "$service" | xargs)  # trim whitespace
        echo
        print_info "=== $service Status ==="
        "$TEMPLATE_FULL_PATH/env/$service.sh" status
    done
}

# Colors for output (consistent across all projects)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_color() {
    echo -e "${1}${2}${NC}"
}

print_header() {
    echo
    print_color "$BLUE" "=============================================="
    print_color "$BLUE" "$1"
    print_color "$BLUE" "=============================================="
}

print_success() {
    print_color "$GREEN" "✅ $1"
}

print_warning() {
    print_color "$YELLOW" "⚠️ $1"
}

print_error() {
    print_color "$RED" "❌ $1"
}

print_info() {
    print_color "$BLUE" "ℹ️ $1"
}

# Delegate command to template service scripts with proper error handling
delegate_to_template() {
    local command="$1"
    shift

    # Ensure we're in template directory
    cd "$TEMPLATE_FULL_PATH" || {
        print_error "Failed to access template directory: $TEMPLATE_FULL_PATH"
        exit 1
    }

    # Execute service command directly
    case "$command" in
        minio|dremio|airflow)
            if [[ -f "./env/$command.sh" ]]; then
                ./env/"$command".sh "$@"
            else
                print_error "Service script not found: ./env/$command.sh"
                exit 1
            fi
            ;;
        logs)
            # Handle logs command for specific service
            local service="$1"
            if [[ -n "$service" && -f "./env/$service.sh" ]]; then
                ./env/"$service".sh logs "${@:2}"
            else
                print_error "Service not specified or script not found: $service"
                return 1
            fi
            ;;
        *)
            print_error "Unknown template command: $command"
            return 1
            ;;
    esac
}

# Standard project status display
show_standard_project_status() {
    local project_title="$1"

    print_header "📊 ${project_title} ENVIRONMENT STATUS"

    # Show enabled services status
    show_enabled_services_status

    echo
    print_color "$BLUE" "🎯 Project Configuration:"
    echo "  Project: ${PROJECT_NAME:-Unknown}"
    echo "  Template: $TEMPLATE_FULL_PATH"
    echo "  Description: ${PROJECT_DESCRIPTION:-No description}"
    echo "  Enabled Services: ${ENABLED_SERVICES:-minio,dremio,airflow}"

    # Show project-specific configuration if available
    if [[ -n "$SIMULATOR_PORT" ]]; then
        echo "  Simulator Port: $SIMULATOR_PORT"
    fi
}

# Standard usage display with customizable sections
show_standard_usage() {
    local script_name="$1"
    local project_title="$2"

    echo "Usage: $script_name {start|stop|status|logs} [service]"
    echo
    echo "Environment Commands:"
    echo "  start     - Start enabled services ($(echo ${ENABLED_SERVICES:-minio,dremio,airflow} | tr ',' ' '))"
    echo "  stop      - Stop all enabled services"
    echo "  status    - Show current status"
    echo "  logs      - Show logs [service]"
    echo
    echo "Individual Service Control:"
    echo "  minio {start|stop|restart|logs}"
    echo "  dremio {start|stop|restart|logs}"
    echo "  airflow {start|stop|restart|logs|create-dag}"
    echo
    echo "Configuration:"
    echo "  Template: $TEMPLATE_FULL_PATH"
    echo "  Project: ${PROJECT_NAME:-Unknown}"
    echo "  Enabled Services: ${ENABLED_SERVICES:-minio,dremio,airflow}"
}

# Validate required tools and dependencies
validate_environment() {
    local missing_tools=()

    # Check for required tools
    if ! command -v podman &> /dev/null; then
        missing_tools+=("podman")
    fi

    if ! command -v curl &> /dev/null; then
        missing_tools+=("curl")
    fi

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        echo "Please install the missing tools and try again."
        exit 1
    fi
}

# Check if services are accessible
check_service_health() {
    local service_name="$1"
    local port="$2"
    local endpoint="${3:-/health}"

    if curl -sf "http://localhost:$port$endpoint" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Standard main function that projects can customize
standard_main() {
    local project_title="$1"
    shift
    local script_name="$(basename "${BASH_SOURCE[1]}")"

    print_header "🎯 ${project_title} ENVIRONMENT"

    # Validate environment
    validate_environment

    case "${1:-status}" in
        start|basic|full)
            start_enabled_services "$1"
            ;;
        stop)
            stop_enabled_services
            ;;
        status)
            show_standard_project_status "$project_title"
            ;;
        logs)
            shift
            if [[ -n "$1" ]]; then
                # Show logs for specific service
                delegate_to_template logs "$1"
            else
                # Show logs for all enabled services
                parse_enabled_services
                for service in "${ENABLED_SERVICES_ARRAY[@]}"; do
                    service=$(echo "$service" | xargs)
                    echo
                    print_info "=== $service Logs ==="
                    "$TEMPLATE_FULL_PATH/env/$service.sh" logs
                done
            fi
            ;;
        minio|dremio|airflow)
            # Direct service control - delegate to template
            delegate_to_template "$@"
            ;;
        help|--help|-h)
            show_standard_usage "$script_name" "$project_title"
            ;;
        *)
            print_error "Unknown command: $1"
            show_standard_usage "$script_name" "$project_title"
            exit 1
            ;;
    esac
}

# =============================================================================
# PROJECT TEMPLATE GENERATOR
# =============================================================================

# Generate a new project setup script
generate_project_setup() {
    local project_name="$1"
    local project_description="$2"
    local target_dir="$3"

    if [[ -z "$project_name" || -z "$target_dir" ]]; then
        echo "Usage: generate_project_setup <project_name> <description> <target_dir>"
        return 1
    fi

    # Create target directory
    mkdir -p "$target_dir"

    # Generate .env file
    cat > "$target_dir/.env" << EOF
# =============================================================================
# ${project_name} Environment Configuration
# =============================================================================

# Project Configuration
PROJECT_NAME="${project_name}"
PROJECT_DESCRIPTION="${project_description:-${project_name} Environment}"

# Template Repository Path (adjust as needed)
TEMPLATE_PATH="../../setup-podman-env"

# Network Configuration
NETWORK_NAME="\${PROJECT_NAME}-network"

# =============================================================================
# CONTAINER CONFIGURATION
# =============================================================================

# MinIO (S3-Compatible Storage)
MINIO_CONTAINER_NAME="\${PROJECT_NAME}-minio"
MINIO_IMAGE="quay.io/minio/minio:latest"
MINIO_PORT="9000"
MINIO_CONSOLE_PORT="9001"
MINIO_VOLUME_NAME="minio-data"
MINIO_MEMORY="256m"
MINIO_ROOT_USER="minioadmin"
MINIO_ROOT_PASSWORD="minioadmin"

# Dremio (SQL Federation Engine)
DREMIO_CONTAINER_NAME="\${PROJECT_NAME}-dremio"
DREMIO_IMAGE="dremio/dremio-oss:latest"
DREMIO_HTTP_PORT="8080"
DREMIO_JDBC_PORT="9047"
DREMIO_VOLUME_NAME="dremio-data"
DREMIO_MEMORY="1g"
DREMIO_STARTUP_TIMEOUT="120"

# Airflow (Workflow Orchestration)
AIRFLOW_CONTAINER_NAME="\${PROJECT_NAME}-airflow"
AIRFLOW_IMAGE="apache/airflow:2.7.0-python3.9"
AIRFLOW_PORT="8090"
AIRFLOW_MEMORY="1g"
AIRFLOW_CPUS="1"
AIRFLOW_STARTUP_TIMEOUT="90"
AIRFLOW_ADMIN_USER="admin"
AIRFLOW_ADMIN_PASSWORD="admin"
AIRFLOW_ADMIN_EMAIL="admin@example.com"

# Airflow Runtime Configuration
AIRFLOW_PARALLELISM="2"
AIRFLOW_MAX_ACTIVE_TASKS_PER_DAG="2"
AIRFLOW_WORKERS="1"

# =============================================================================
# RESOURCE LIMITS
# =============================================================================
BASIC_SETUP_MEMORY="1.3GB"
FULL_SETUP_MEMORY="2.3GB"

# =============================================================================
# DEVELOPMENT FLAGS
# =============================================================================
DEVELOPMENT_MODE="true"
AUTO_CREATE_VOLUMES="true"
CLEANUP_ON_EXIT="false"
VERBOSE_LOGGING="false"
DEFAULT_LOG_LINES="20"
EOF

    # Generate setup-env.sh script
    cat > "$target_dir/setup-env.sh" << 'EOF'
#!/bin/bash
# PROJECT_NAME Environment Setup
# Leverages setup-podman-env template with project-specific configuration

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Source the project wrapper framework
TEMPLATE_DIR="$(cd "$SCRIPT_DIR" && source .env && echo "$TEMPLATE_PATH")"
if [[ -f "$TEMPLATE_DIR/project-wrapper.sh" ]]; then
    source "$TEMPLATE_DIR/project-wrapper.sh"
else
    echo "❌ Project wrapper not found. Please ensure setup-podman-env template is available."
    exit 1
fi

# Initialize project wrapper
init_project_wrapper "$SCRIPT_DIR" "PROJECT_NAME"

# Use standard main function with project customizations
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    standard_main "PROJECT_NAME" "$@"
fi
EOF

    # Replace placeholders
    sed -i "s/PROJECT_NAME/${project_name}/g" "$target_dir/setup-env.sh"

    # Make executable
    chmod +x "$target_dir/setup-env.sh"

    print_success "Generated project setup for '$project_name' in $target_dir"
    print_info "Files created:"
    echo "  - $target_dir/.env"
    echo "  - $target_dir/setup-env.sh"
    echo ""
    print_info "Usage:"
    echo "  cd $target_dir"
    echo "  ./setup-env.sh basic"
}

# =============================================================================
# HELP FUNCTIONS
# =============================================================================

show_wrapper_usage() {
    echo "Project Wrapper Framework for setup-podman-env"
    echo
    echo "Usage:"
    echo "  source project-wrapper.sh"
    echo "  init_project_wrapper \"\$SCRIPT_DIR\" \"project-name\""
    echo "  standard_main \"Project Title\" \"\$@\""
    echo
    echo "Generator:"
    echo "  ./project-wrapper.sh generate <name> <description> <target_dir>"
    echo
    echo "Available Functions:"
    echo "  - init_project_wrapper: Initialize project configuration"
    echo "  - delegate_to_template: Execute template commands"
    echo "  - show_standard_project_status: Display project status"
    echo "  - show_standard_usage: Display usage information"
    echo "  - validate_environment: Check required tools"
    echo "  - standard_main: Standard main function"
}

# If called directly, handle generator command
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-help}" in
        generate)
            generate_project_setup "$2" "$3" "$4"
            ;;
        *)
            show_wrapper_usage
            ;;
    esac
fi