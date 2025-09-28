#!/bin/bash
# Airflow Orchestration Engine pod management
#
# STARTUP INFO:
# - Startup Time: 2-4 minutes (database init + web server)
# - Health Check: http://localhost:8090/health (default)
# - Timeout: Configurable via AIRFLOW_STARTUP_TIMEOUT (default: 300s/5min)
# - Memory Usage: ~1GB (configurable via AIRFLOW_MEMORY)
# - Executor: SequentialExecutor (SQLite compatible)
#
# OBSERVED INITIALIZATION PHASES:
# 1. Container start (~15s)
# 2. Database initialization (~45-60s)
# 3. User creation (~20s)
# 4. Web server startup (~30-45s)
# 5. Scheduler initialization (~30-60s)
#
# TROUBLESHOOTING:
# - Check logs: ./setup-env.sh logs airflow
# - Monitor resources: podman stats $CONTAINER_NAME
# - Database issues: Check SQLite + SequentialExecutor config
# - Web UI not ready: Wait for "Airflow webserver started" in logs

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/common.sh"

# Use .env configuration variables
CONTAINER_NAME="$AIRFLOW_CONTAINER_NAME"
IMAGE="$AIRFLOW_IMAGE"
PORT="$AIRFLOW_PORT"

start_airflow() {
    print_header "🚀 STARTING AIRFLOW"
    ensure_network

    if start_existing_container "$CONTAINER_NAME"; then
        wait_for_service "Airflow" "http://localhost:$PORT/health" "$AIRFLOW_STARTUP_TIMEOUT"
        print_color "$BLUE" "Web UI: http://localhost:$PORT (admin/admin)"
        return 0
    fi

    # Create directories
    local base_dir="$(get_host_path "airflow-local")"
    mkdir -p "$base_dir"/{dags,logs,plugins,config}

    # Create minimal config
    cat > "$base_dir/config/airflow.cfg" << 'EOF'
[core]
executor = SequentialExecutor
sql_alchemy_conn = sqlite:////opt/airflow/airflow.db
load_examples = False
dags_folder = /opt/airflow/dags

[webserver]
web_server_port = 8080
workers = 1

[scheduler]
catchup_by_default = False

[logging]
logging_level = WARNING
EOF

    print_color "$YELLOW" "Creating Airflow container (this will take 2-3 minutes)..."
    podman run -d \
        --name "$CONTAINER_NAME" \
        --network "$NETWORK_NAME" \
        -p "${PORT}:8080" \
        --memory="$AIRFLOW_MEMORY" \
        --cpus="$AIRFLOW_CPUS" \
        -v "$base_dir/dags:/opt/airflow/dags" \
        -v "$base_dir/logs:/opt/airflow/logs" \
        -v "$base_dir/plugins:/opt/airflow/plugins" \
        -v "$base_dir/config/airflow.cfg:/opt/airflow/airflow.cfg" \
        -e "AIRFLOW__CORE__EXECUTOR=SequentialExecutor" \
        -e "AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=sqlite:////opt/airflow/airflow.db" \
        -e "AIRFLOW__CORE__LOAD_EXAMPLES=False" \
        -e "AIRFLOW__WEBSERVER__WORKERS=1" \
        -e "AIRFLOW__CORE__PARALLELISM=2" \
        -e "AIRFLOW__CORE__MAX_ACTIVE_TASKS_PER_DAG=2" \
        "$IMAGE" \
        bash -c "
            airflow db init &&
            airflow users create --username admin --password admin --firstname Admin --lastname User --role Admin --email admin@example.com &&
            airflow standalone
        " >/dev/null

    print_color "$GREEN" "✓ Airflow container created"
    wait_for_service "Airflow" "http://localhost:$PORT/health" "$AIRFLOW_STARTUP_TIMEOUT"
    print_color "$BLUE" "Web UI: http://localhost:$PORT (admin/admin)"
    print_color "$BLUE" "DAGs directory: ./airflow-local/dags/"
}

stop_airflow() {
    print_header "🛑 STOPPING AIRFLOW"
    stop_container "$CONTAINER_NAME"
}

logs_airflow() {
    get_container_logs "$CONTAINER_NAME" "${1:-20}"
}

status_airflow() {
    print_header "📊 AIRFLOW STATUS"

    if container_running "$CONTAINER_NAME"; then
        print_color "$GREEN" "✓ Airflow container is running"
        print_color "$BLUE" "Container: $CONTAINER_NAME"
        print_color "$BLUE" "Web UI: http://localhost:$PORT"
        print_color "$BLUE" "Admin credentials: admin/admin"

        # Check if web UI is responding
        if curl -sf "http://localhost:$PORT/health" >/dev/null 2>&1; then
            print_color "$GREEN" "✓ Web UI is accessible"
        else
            print_color "$YELLOW" "⚠ Web UI not yet ready"
        fi
    elif container_exists "$CONTAINER_NAME"; then
        print_color "$YELLOW" "⚠ Airflow container exists but is not running"
        print_color "$BLUE" "Run: $0 start"
    else
        print_color "$RED" "✗ Airflow container does not exist"
        print_color "$BLUE" "Run: $0 start"
    fi
}

create_tcp_deriv_dag() {
    local base_dir="$(get_host_path "airflow-local")"
    if [[ ! -d "$base_dir/dags" ]]; then
        print_color "$RED" "Airflow not initialized. Start Airflow first."
        return 1
    fi

    print_color "$YELLOW" "Creating TCP/DERIV/SNAPSHOT regression DAG..."
    cat > "$base_dir/dags/tcp_deriv_regression.py" << 'EOF'
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.dummy_operator import DummyOperator
from airflow.operators.python_operator import PythonOperator
import requests
import time

default_args = {
    'owner': 'risk-team',
    'depends_on_past': True,
    'start_date': datetime(2025, 1, 1),
    'retries': 0,
    'retry_delay': timedelta(minutes=5),
    'catchup': False
}

dag = DAG(
    'tcp_deriv_snapshot_regression',
    default_args=default_args,
    description='TCP/DERIV/SNAPSHOT regression testing with fail-fast',
    schedule_interval=None,
    max_active_runs=1,
    tags=['regression', 'tcp', 'deriv', 'snapshot']
)

SIMULATOR_URL = "$SIMULATOR_URL"

def trigger_and_validate_pipeline(pipeline_name, **context):
    print(f"🚀 Starting {pipeline_name}")
    response = requests.post(f'{SIMULATOR_URL}/api/v1/pipeline/trigger',
                           json={'pipeline_name': pipeline_name, 'run_type': 'baseline'})

    if response.status_code != 200:
        raise Exception(f"Failed to start {pipeline_name}: {response.text}")

    execution_id = response.json()['execution_id']
    print(f"📋 Execution ID: {execution_id}")

    max_wait = 300
    wait_time = 0

    while wait_time < max_wait:
        status_response = requests.get(f'{SIMULATOR_URL}/api/v1/pipeline/status/{execution_id}')
        status_data = status_response.json()
        status = status_data['status']

        if status == 'COMPLETED':
            validation = status_data.get('validation_result', {})
            if validation.get('blocking') and not validation.get('success'):
                raise Exception(f"Pipeline {pipeline_name} failed validation: {validation.get('message')}")
            if validation.get('hasDataDifferences'):
                print(f"⚠️ Data differences detected in {pipeline_name}: {validation.get('message')}")
            print(f"✅ {pipeline_name} completed successfully")
            return execution_id
        elif status == 'FAILED':
            error_msg = status_data.get('error_message', 'Unknown error')
            raise Exception(f"Pipeline {pipeline_name} execution failed: {error_msg}")

        print(f"⏳ {pipeline_name}: {status}...")
        time.sleep(10)
        wait_time += 10

    raise Exception(f"Pipeline {pipeline_name} timed out after {max_wait} seconds")

# TCP Stream
tcp_staging = PythonOperator(task_id='tcp_staging', python_callable=trigger_and_validate_pipeline, op_kwargs={'pipeline_name': 'TCP_STAGING'}, dag=dag)
tcp_exposure = PythonOperator(task_id='tcp_exposure', python_callable=trigger_and_validate_pipeline, op_kwargs={'pipeline_name': 'TCP_EXPOSURE'}, dag=dag)
tcp_shock = PythonOperator(task_id='tcp_shock', python_callable=trigger_and_validate_pipeline, op_kwargs={'pipeline_name': 'TCP_SHOCK'}, dag=dag)
tcp_stress = PythonOperator(task_id='tcp_stress', python_callable=trigger_and_validate_pipeline, op_kwargs={'pipeline_name': 'TCP_STRESS'}, dag=dag)

# DERIV Stream
deriv_staging = PythonOperator(task_id='deriv_staging', python_callable=trigger_and_validate_pipeline, op_kwargs={'pipeline_name': 'DERIV_STAGING'}, dag=dag)
deriv_exposure = PythonOperator(task_id='deriv_exposure', python_callable=trigger_and_validate_pipeline, op_kwargs={'pipeline_name': 'DERIV_EXPOSURE'}, dag=dag)
deriv_shock = PythonOperator(task_id='deriv_shock', python_callable=trigger_and_validate_pipeline, op_kwargs={'pipeline_name': 'DERIV_SHOCK'}, dag=dag)
deriv_stress = PythonOperator(task_id='deriv_stress', python_callable=trigger_and_validate_pipeline, op_kwargs={'pipeline_name': 'DERIV_STRESS'}, dag=dag)

# Sync points
tcp_complete = DummyOperator(task_id='tcp_complete', dag=dag)
deriv_complete = DummyOperator(task_id='deriv_complete', dag=dag)

# SNAPSHOT
snapshot = PythonOperator(task_id='snapshot', python_callable=trigger_and_validate_pipeline, op_kwargs={'pipeline_name': 'SNAPSHOT'}, dag=dag)

# Dependencies
tcp_staging >> tcp_exposure >> tcp_shock >> tcp_stress >> tcp_complete
deriv_staging >> deriv_exposure >> deriv_shock >> deriv_stress >> deriv_complete
[tcp_complete, deriv_complete] >> snapshot
EOF

    print_color "$GREEN" "✓ TCP/DERIV/SNAPSHOT DAG created"
    print_color "$BLUE" "Location: ./airflow-local/dags/tcp_deriv_regression.py"
}

case "${1:-start}" in
    start) start_airflow ;;
    stop) stop_airflow ;;
    restart) stop_airflow && start_airflow ;;
    status) status_airflow ;;
    logs) logs_airflow "$2" ;;
    create-dag) create_tcp_deriv_dag ;;
    *) echo "Usage: $0 {start|stop|restart|status|logs|create-dag}" ;;
esac