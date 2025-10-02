# Modular Podman Environment Setup

A reusable, modular environment setup system for managing containerized development environments with Podman. Designed for easy configuration and cross-project portability.

## ✨ Latest Updates

### 🐳 **Project Directory Mounting** (v2.1)
- **NEW: PROJECT_DIR support** - Mount your project directory into Spark containers for local testing
- **Seamless local development** - Access JARs, configs, and data from within containers
- **Bitnami Spark compatibility** - Updated Spark template to work with `bitnami/spark` images
- **Enhanced common utilities** - Added `print_info`, `print_success`, `print_warning`, `print_error`, `create_volume` functions

### 🔧 **Port Conflict Resolution** (v2.0)
- **Fixed all service port conflicts** - No more collisions between Dremio/Spark (8080) or Redpanda/Spark workers
- **Conflict-free defaults**: Spark Master UI moved to 8070, Workers to 8200+, Redpanda services to 8100+
- **Comprehensive port allocation strategy** with dedicated ranges for different service types

### 🚀 **Project Wrapper Framework** (v2.0)
- **Reduced setup complexity**: Project scripts now ~22 lines (down from ~130 lines)
- **Reusable functions**: Common utilities abstracted in `project-wrapper.sh`
- **Flexible service selection**: Choose exactly which services your project needs
- **Cross-project portability**: Template works seamlessly across multiple projects

### 📦 **8 Production-Ready Services**
Complete containerized development stack with health checks, logging, and status monitoring.

## 🚀 Quick Start

### For New Projects

```bash
# 1. Copy this template to your project location
cp -r setup-podman-env /path/to/your/project/

# 2. Generate a new project setup
cd setup-podman-env
./project-wrapper.sh generate my-project "My Project Description" ../my-project/scripts

# 3. Configure your project
cd ../my-project/scripts
cp .env.example .env  # If needed
# Edit .env with your specific service selection and configuration

# 4. Start your services
./setup-env.sh start
```

### For Existing Projects

```bash
# 1. Add template as dependency
# Option A: Copy template (not recommended for production)
cp -r setup-podman-env /path/to/your/project/

# Option B: Git submodule (recommended)
git submodule add https://github.com/gauravsri/setup-podman-env.git setup-podman-env

# 2. Create project-specific setup using project wrapper
# See project-wrapper.sh for common functions and patterns
```

## 🔗 Git Submodule Integration (Recommended)

### Why Use Git Submodule?
- ✅ **Version Control**: Template version is tracked with your project
- ✅ **Portability**: Works on any machine after `git clone --recursive`
- ✅ **Team Collaboration**: Everyone gets the same template version
- ✅ **Easy Updates**: Update template with `git submodule update --remote`
- ✅ **Independence**: No dependency on local file system layout

### Setup with Git Submodule

#### Step 1: Add Submodule to Your Project
```bash
cd your-project
git submodule add https://github.com/gauravsri/setup-podman-env.git setup-podman-env
```

#### Step 2: Configure Your Project
```bash
# Create scripts/.env with your configuration
cat > scripts/.env << 'EOF'
PROJECT_NAME="my-project"
PROJECT_DESCRIPTION="My Project Description"

# Template path for git submodule
TEMPLATE_PATH="../setup-podman-env"

# Project directory to mount in containers (optional, for Spark)
# Use Windows-style path for Podman on Windows
PROJECT_DIR="C:/Users/your-name/path/to/project"

# Choose your services
ENABLED_SERVICES="minio,dremio,airflow"

# Network configuration
NETWORK_NAME="${PROJECT_NAME}-network"
EOF
```

#### Step 3: Create Project Setup Script
```bash
# Create scripts/setup-env.sh
cat > scripts/setup-env.sh << 'EOF'
#!/bin/bash
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Load project wrapper framework from submodule
source "$SCRIPT_DIR/../setup-podman-env/project-wrapper.sh"

# Initialize with project configuration
init_project_wrapper "$SCRIPT_DIR" "my-project"

# Handle all commands via standard framework
standard_main "MY PROJECT" "$@"
EOF

chmod +x scripts/setup-env.sh
```

#### Step 4: Commit and Push
```bash
git add .gitmodules setup-podman-env scripts/
git commit -m "Add setup-podman-env as git submodule"
git push
```

### Working with Git Submodules

#### For New Team Members
```bash
# Clone with submodules
git clone --recursive https://github.com/your-org/your-project.git

# Or initialize submodules after clone
git clone https://github.com/your-org/your-project.git
cd your-project
git submodule update --init --recursive
```

#### Updating Template Version
```bash
# Update to latest template version
git submodule update --remote setup-podman-env

# Commit the template update
git add setup-podman-env
git commit -m "Update setup-podman-env to latest version"
git push
```

#### Working with Specific Template Versions
```bash
# Check current template version
cd setup-podman-env
git log --oneline -5

# Update to specific version
git checkout f4ab1b2  # specific commit hash
cd ..
git add setup-podman-env
git commit -m "Pin setup-podman-env to version f4ab1b2"
```

### Real-World Example

Here's how the **spark-e2e-regression** project uses this template:

```bash
# Project structure
spark-e2e-regression/
├── .gitmodules                    # Submodule configuration
├── setup-podman-env/              # Git submodule (this template)
├── scripts/
│   ├── .env                      # Project-specific configuration
│   └── setup-env.sh              # 22-line wrapper script
└── other-project-files...

# .env configuration
PROJECT_NAME="spark-e2e"
TEMPLATE_PATH="../setup-podman-env"
ENABLED_SERVICES="minio,dremio,airflow"

# Usage
cd scripts
./setup-env.sh start    # Start services
./setup-env.sh status   # Check status
./setup-env.sh logs     # View logs
```

### Troubleshooting Git Submodules

#### Submodule Not Initialized
```bash
# If you see "setup-podman-env directory is empty"
git submodule update --init --recursive
```

#### Submodule Update Conflicts
```bash
# Reset submodule to tracked version
git submodule update --force
```

#### Checking Submodule Status
```bash
# View submodule status
git submodule status

# View submodule details
git submodule summary
```

## 📦 Available Services

### Data Storage & Processing
- **MinIO**: S3-compatible object storage (~256MB)
- **Dremio**: SQL federation engine with Delta Lake support (~1GB)
- **Apache Spark**: Distributed computing with master + workers (~1GB+ per worker)

### Workflow & Orchestration
- **Airflow**: Workflow orchestration with DAG support (~1GB)

### Streaming & Messaging
- **Redpanda**: Kafka-compatible streaming platform (~1GB)

### Search & Analytics
- **ZincSearch**: Lightweight search engine with REST API (~512MB)

### Authentication & Communication
- **Dex**: OIDC identity provider for authentication (~256MB)
- **Postfix**: Email server for SMTP relay (~256MB)

### Memory Usage Examples
- **Basic Data Stack**: ~1.3GB (MinIO + Dremio)
- **Full Orchestration**: ~2.3GB (MinIO + Dremio + Airflow)
- **Streaming Platform**: ~2GB (Redpanda + Spark)
- **Search Stack**: ~768MB (MinIO + ZincSearch)
- **Complete Platform**: ~5GB+ (All services)

## 🎯 Commands

### Project Commands (used in projects that leverage this template)
```bash
# These commands are available in projects using the template
./setup-env.sh start     # Start enabled services
./setup-env.sh stop      # Stop all enabled services
./setup-env.sh status    # Show current status
./setup-env.sh logs      # Show logs (all enabled services)
./setup-env.sh logs minio # Show specific service logs
```

### Template Management
```bash
# Generate new project setup
./project-wrapper.sh generate <name> <description> <target_dir>

# Show template usage
./project-wrapper.sh help
```

### Individual Service Control
```bash
# Data Storage & Processing
./env/minio.sh {start|stop|restart|logs}
./env/dremio.sh {start|stop|restart|logs}
./env/spark.sh {start|stop|restart|logs|status|submit-example}

# Workflow & Orchestration
./env/airflow.sh {start|stop|restart|logs|create-dag}

# Streaming & Messaging
./env/redpanda.sh {start|stop|restart|logs|status}

# Search & Analytics
./env/zincsearch.sh {start|stop|restart|logs|status}

# Authentication & Communication
./env/dex.sh {start|stop|restart|logs|status|test}
./env/postfix.sh {start|stop|restart|logs|status|test}
```

## ⚙️ Configuration

### Environment Setup
1. Generate project setup (for new projects):
   ```bash
   ./project-wrapper.sh generate my-project "Description" ../my-project/scripts
   ```

2. Or copy the example configuration (for manual setup):
   ```bash
   cp env/.env.example .env
   ```

3. Customize for your project:
   ```bash
   # Project Configuration
   PROJECT_NAME="my-awesome-project"
   PROJECT_DESCRIPTION="My Awesome Project"

   # Service Selection - Choose what you need
   ENABLED_SERVICES="minio,dremio,airflow"        # Full data stack
   # ENABLED_SERVICES="minio,zincsearch"          # Storage + search
   # ENABLED_SERVICES="redpanda,spark"            # Streaming + processing
   # ENABLED_SERVICES="dex,postfix"               # Auth + email

   # Ports (avoid conflicts with existing services)
   MINIO_PORT="9000"                    # MinIO API
   DREMIO_HTTP_PORT="8080"              # Dremio web UI
   AIRFLOW_PORT="8090"                  # Airflow web UI
   ZINCSEARCH_HTTP_PORT="4080"          # ZincSearch API
   REDPANDA_KAFKA_PORT="9092"           # Kafka API
   DEX_HTTP_PORT="5556"                 # Dex OIDC
   POSTFIX_SMTP_PORT="1587"             # SMTP
   SPARK_MASTER_WEB_PORT="8080"         # Spark UI (may conflict with Dremio)

   # Resources (adjust for your hardware)
   MINIO_MEMORY="256m"
   DREMIO_MEMORY="1g"
   AIRFLOW_MEMORY="1g"
   SPARK_WORKER_COUNT="2"               # Number of Spark workers
   ```

### Key Configuration Sections

#### Project Settings
- `PROJECT_NAME`: Used as prefix for all container names
- `NETWORK_NAME`: Podman network for inter-container communication

#### Service Ports
- MinIO: API (9000) + Console (9001)
- Dremio: Web UI (8080) + JDBC (9047)
- Airflow: Web UI (8090)

#### Resource Limits
- Memory limits per service
- CPU limits for Airflow
- Startup timeouts

#### Integration Settings
- Simulator URL for Airflow DAGs
- Admin credentials
- Development flags

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│     MinIO       │    │     Dremio      │    │    Airflow      │
│  (S3 Storage)   │◄──►│  (SQL Engine)   │◄──►│ (Orchestration) │
│   Port: 9000    │    │   Port: 8080    │    │   Port: 8090    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │  Podman Network │
                    │ project-network │
                    └─────────────────┘
```

## 🔧 Service Details

### Data Storage & Processing

#### MinIO (S3-Compatible Storage)
- **Purpose**: Object storage for data files, compatible with AWS S3 API
- **Web Console**: http://localhost:9001
- **API Endpoint**: http://localhost:9000
- **Default Credentials**: minioadmin/minioadmin
- **Data Persistence**: Named volume `minio-data`
- **Use Cases**: Data lake storage, backup, file serving

#### Dremio (SQL Federation Engine)
- **Purpose**: SQL queries across multiple data sources with acceleration
- **Web UI**: http://localhost:8080
- **JDBC**: `jdbc:dremio:direct=localhost:9047`
- **Features**: Delta Lake support, query optimization, data virtualization
- **Data Persistence**: Named volume `dremio-data`
- **Use Cases**: Data analytics, BI queries, data federation

#### Apache Spark (Distributed Computing)
- **Purpose**: Large-scale data processing and analytics
- **Master UI**: http://localhost:8070 (default, configurable)
- **Worker UI**: http://localhost:8200+ (one per worker)
- **Master URL**: spark://localhost:7077
- **Features**: Batch processing, streaming, ML, graph processing
- **Configuration**: Configurable workers, memory, cores
- **Project Mounting**: Set `PROJECT_DIR` in .env to mount your project at `/app` in containers
- **Image**: Uses `bitnami/spark` (tested with 3.5.3)
- **Use Cases**: ETL pipelines, data science, machine learning, local Spark job testing

### Workflow & Orchestration

#### Airflow (Workflow Orchestration)
- **Purpose**: DAG-based workflow management and scheduling
- **Web UI**: http://localhost:8090
- **Default Credentials**: admin/admin
- **Features**: Python operators, scheduler, REST API, task dependencies
- **DAG Location**: `./airflow-local/dags/`
- **Use Cases**: Data pipelines, job scheduling, workflow automation

### Streaming & Messaging

#### Redpanda (Kafka-Compatible Streaming)
- **Purpose**: High-performance streaming platform, Kafka API compatible
- **Kafka API**: localhost:9092
- **Admin API**: http://localhost:9644
- **REST Proxy**: http://localhost:8082
- **Schema Registry**: http://localhost:8081
- **Features**: Real-time streaming, event sourcing, low latency
- **Use Cases**: Event streaming, microservices communication, log aggregation

### Search & Analytics

#### ZincSearch (Lightweight Search Engine)
- **Purpose**: Full-text search with Elasticsearch-compatible API
- **Web UI**: http://localhost:4080
- **API Docs**: http://localhost:4080/ui/
- **Default Credentials**: admin/admin
- **Features**: Full-text search, analytics, REST API, lightweight
- **Use Cases**: Application search, log search, document indexing

### Authentication & Communication

#### Dex (OIDC Identity Provider)
- **Purpose**: OpenID Connect and OAuth2 authentication service
- **OIDC Issuer**: http://localhost:5556/dex
- **Well-known Config**: http://localhost:5556/dex/.well-known/openid_configuration
- **Test Users**: admin@example.com/password, user@example.com/password
- **Features**: Multiple connectors, OIDC/OAuth2, identity federation
- **Use Cases**: SSO, API authentication, identity management

#### Postfix (Email Server)
- **Purpose**: SMTP email relay for application notifications
- **SMTP Port**: localhost:1587
- **Features**: Email relay, SMTP authentication, configurable domains
- **Configuration**: Support for external relay hosts
- **Use Cases**: Application emails, notifications, alerts

## 📁 Directory Structure

```
setup-podman-env/
├── setup-env.sh           # Main orchestration script
├── env/
│   ├── .env               # Project configuration
│   ├── .env.example       # Configuration template
│   ├── common.sh          # Shared utilities
│   ├── minio.sh           # MinIO management
│   ├── dremio.sh          # Dremio management
│   └── airflow.sh         # Airflow management
├── airflow-local/         # Created when Airflow starts
│   ├── dags/              # DAG files
│   ├── logs/              # Airflow logs
│   └── plugins/           # Custom plugins
└── README.md              # This file
```

## 🚀 Project Wrapper Framework

The project wrapper framework reduces project setup complexity and ensures consistency across projects.

### Key Benefits
- **Minimal Project Code**: Setup scripts reduced from ~130 to ~22 lines
- **Reusable Functions**: Common utilities abstracted in `project-wrapper.sh`
- **Service Selection**: Flexible `ENABLED_SERVICES` configuration
- **Validation**: Automatic template and configuration validation
- **Error Handling**: Comprehensive error messages and troubleshooting

### Project Setup Example
```bash
# In your project's scripts/setup-env.sh
#!/bin/bash
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Load project wrapper framework
source "$SCRIPT_DIR/../setup-podman-env/project-wrapper.sh"

# Initialize with project-specific configuration
init_project_wrapper "$SCRIPT_DIR" "my-project"

# Standard main function handles all commands
standard_main "MY PROJECT" "$@"
```

### Available Functions
- `init_project_wrapper()`: Load configuration and validate template
- `parse_enabled_services()`: Parse and validate ENABLED_SERVICES
- `start_enabled_services()`: Start only the services your project needs
- `stop_enabled_services()`: Stop all enabled services
- `show_services_status()`: Display status of enabled services
- `standard_main()`: Handle all standard commands (start/stop/status/logs)

## 🐳 Project Directory Mounting (Spark)

The Spark service supports mounting your project directory into containers for local development and testing.

### Configuration

In your `scripts/.env`:
```bash
# Mount your project directory at /app in Spark containers
PROJECT_DIR="C:/Users/your-name/path/to/project"  # Windows path
# or
PROJECT_DIR="/home/user/projects/my-project"      # Linux path
```

### How It Works

When `PROJECT_DIR` is set:
- **Spark Master**: Your project is mounted at `/app` with read/write access
- **Spark Workers**: Same mount ensures consistent access across cluster
- **Volume Flag**: Uses `-v $PROJECT_DIR:/app:z` for SELinux compatibility

### Use Cases

#### Running Spark Jobs Locally
```bash
# Inside Spark container
podman exec spark-master-hbase sh -c '
  /opt/bitnami/spark/bin/spark-submit \
    --class com.example.MyApp \
    --master spark://spark-master:7077 \
    /app/target/my-app-1.0.0.jar \
    -c /app/config/my-config.properties
'
```

#### Accessing Project Resources
```bash
# Your project structure is available at /app
/app/
├── target/
│   └── my-app.jar          # Built JARs
├── config/
│   └── application.conf    # Configuration files
├── data/
│   └── input.parquet       # Test data
└── src/
    └── main/               # Source code
```

#### Example: HBase to Delta Converter
```bash
# From hbase-delta-converter project
PROJECT_DIR="C:/Users/gaura/Local/claude/hbase-delta-convertor"
ENABLED_SERVICES="spark"

# Spark containers can now access:
# - /app/target/hbase-delta-convertor-1.0.0.jar
# - /app/config/user_table_conversion_local.properties
# - /app/hbase-snapshot/ (test data)
# - /app/delta-output/ (write results)
```

### Benefits

✅ **No JAR copying** - JARs built locally are immediately available in containers
✅ **Live configuration** - Edit configs and rerun without container rebuild
✅ **Shared test data** - Use same data for local and containerized testing
✅ **Output persistence** - Results written to `/app` persist on host

## 🛠️ Development Workflow

### For New Projects
1. Use the project generator: `./project-wrapper.sh generate my-project "Description" target/path`
2. Customize the generated `.env` with your service selection and settings
3. Start your environment: `./setup-env.sh start`
4. Develop your application using the running services
5. Use individual service scripts for troubleshooting: `./env/service.sh status`

### For Existing Projects
1. Add template as dependency (copy or git submodule)
2. Create project-specific setup-env.sh using project-wrapper.sh patterns
3. Migrate existing container configurations to use the template's service scripts
4. Configure ENABLED_SERVICES in your .env to match your needs

### Troubleshooting
```bash
# Check service status (in projects using the template)
./setup-env.sh status

# View logs for all enabled services (in projects)
./setup-env.sh logs

# View logs for specific service (direct template access)
./env/dremio.sh logs 50    # Last 50 lines

# Restart problematic service (direct template access)
./env/minio.sh restart

# Test individual service (from template directory)
./env/zincsearch.sh status
./env/spark.sh submit-example
```

## 🔍 Monitoring & Logs

### Service URLs (conflict-free default ports, configurable in .env)
- **MinIO Console**: http://localhost:9001
- **Dremio Web UI**: http://localhost:8080
- **Airflow Web UI**: http://localhost:8090
- **ZincSearch API**: http://localhost:4080
- **Redpanda Admin**: http://localhost:9644
- **Redpanda REST Proxy**: http://localhost:8100 ✅ **(moved from 8082)**
- **Redpanda Schema Registry**: http://localhost:8101 ✅ **(moved from 8081)**
- **Dex OIDC**: http://localhost:5556/dex
- **Spark Master UI**: http://localhost:8070 ✅ **(moved from 8080)**
- **Spark Worker UIs**: http://localhost:8200+ ✅ **(moved from 8081+)**
- **Postfix SMTP**: localhost:1587

### 🔧 Port Conflict Resolution
All port conflicts have been resolved in v2.0:
- **Dremio (8080) vs Spark Master (8080)** → Spark moved to **8070**
- **Redpanda Schema Registry (8081) vs Spark Worker 1 (8081)** → Redpanda moved to **8101**, Spark to **8200**
- **Redpanda REST Proxy (8082) vs Spark Worker 2 (8082)** → Redpanda moved to **8100**

You can now safely enable any combination of services without port conflicts!

### Log Access
```bash
# All service logs
./setup-env.sh logs

# Specific service logs
./env/minio.sh logs
./env/dremio.sh logs 100
./env/airflow.sh logs
```

### Resource Monitoring
```bash
# Container status
podman ps --filter "name=${PROJECT_NAME}-"

# Memory usage
podman stats --filter "name=${PROJECT_NAME}-"
```

## 🚀 Integration Examples

### Service Combinations by Use Case

#### Data Analytics Stack
```bash
ENABLED_SERVICES="minio,dremio,zincsearch"
# Use MinIO for data lake, Dremio for SQL queries, ZincSearch for log analytics
```

#### Real-time Processing Platform
```bash
ENABLED_SERVICES="redpanda,spark,minio"
# Stream data through Redpanda, process with Spark, store results in MinIO
```

#### Complete Data Platform
```bash
ENABLED_SERVICES="minio,dremio,airflow,redpanda,spark,zincsearch"
# Full data platform with storage, processing, orchestration, and search
```

#### Microservices Platform
```bash
ENABLED_SERVICES="dex,postfix,redpanda"
# Authentication, email notifications, and service communication
```

## ⏱️ Service Startup & Initialization

Understanding service startup times and proper initialization procedures is crucial for reliable development environments.

### Startup Timeline & Behavior

| Service | Startup Time | Health Check | Notes |
|---------|-------------|--------------|-------|
| **MinIO** | ~30-40 seconds | `/minio/health/live` | ✅ Fast startup (includes network setup) |
| **Dremio** | ~3-12 minutes | `/` (root endpoint) | ⚠️ Very slow startup, memory-intensive JVM init |
| **Airflow** | ~2-4 minutes | `/health` | ⚠️ Database init + web server startup |
| **Spark Master** | ~15-20 seconds | `:8070` (web UI) | ✅ Quick startup |
| **Spark Worker** | ~10-15 seconds | `:8200+` (web UI) | ✅ Fast, depends on master |
| **Redpanda** | ~20-40 seconds | Admin API `:9644` | ✅ Moderate startup |
| **ZincSearch** | ~10-15 seconds | `/api/index` | ✅ Fast startup |
| **Dex** | ~5-10 seconds | `/.well-known/openid_configuration` | ✅ Very fast |

### Timeout Configuration

Services have configurable startup timeouts in `.env`:

```bash
# Service-specific timeouts (in seconds) - Based on observed behavior + 20% buffer
DREMIO_STARTUP_TIMEOUT="720"    # Dremio can take up to 12 minutes
AIRFLOW_STARTUP_TIMEOUT="300"   # Airflow can take up to 4 minutes
# MinIO, Spark, others: No timeout needed (under 1 minute)
```

### Monitoring Startup Progress

```bash
# Check overall status
./setup-env.sh status

# Monitor specific service logs during startup
./setup-env.sh logs dremio    # Watch Dremio initialization
./setup-env.sh logs airflow   # Monitor Airflow web server startup

# Watch containers in real-time
podman ps -a --filter name=your-project

# Monitor resource usage during startup
podman stats your-project-dremio
```

### Startup Best Practices

#### 1. Staged Startup (Recommended for Low-End Hardware)
```bash
# Start lightweight services first
./setup-env.sh minio start
./setup-env.sh zincsearch start

# Wait for them to be ready, then start heavy services
./setup-env.sh dremio start    # This will take 3-12 minutes
./setup-env.sh airflow start   # Start after Dremio is ready
```

#### 2. Full Environment Startup
```bash
# Start all enabled services (defined in ENABLED_SERVICES)
./setup-env.sh start
# Script automatically waits for each service with appropriate timeouts
```

#### 3. Health Check Verification
```bash
# Manual health checks
curl -sf http://localhost:9000/minio/health/live     # MinIO
curl -sf http://localhost:8080                      # Dremio (may take up to 12 minutes)
curl -sf http://localhost:8090/health              # Airflow
curl -sf http://localhost:8070                     # Spark Master
```

### Troubleshooting Slow Startups

#### Dremio Taking Too Long?
```bash
# Check logs for initialization progress
./setup-env.sh logs dremio

# Common startup phases:
# 1. "Starting Dremio..." - Container starting
# 2. "Initializing metadata store..." - Database setup
# 3. "Web server started..." - Ready for connections

# Dremio startup can take 3-12 minutes - be patient!
# If stuck, check system resources
podman stats spark-e2e-dremio
```

#### Airflow Startup Issues?
```bash
# Check database initialization
./setup-env.sh logs airflow | grep -E "(database|db init|migration)"

# Verify SQLite configuration (should use SequentialExecutor)
./setup-env.sh logs airflow | grep -E "(executor|sqlite)"
```

#### Out of Memory?
```bash
# Check total memory usage
podman stats

# Adjust memory limits in .env
DREMIO_MEMORY="512m"     # Reduce from 1g
AIRFLOW_MEMORY="512m"    # Reduce from 1g
```

### Hardware-Specific Recommendations

#### Low-End Hardware (≤8GB RAM)
- Start services individually with monitoring
- Use basic service combinations (avoid running all 8 services simultaneously)
- Increase timeouts: `DREMIO_STARTUP_TIMEOUT="720"` (12min), `AIRFLOW_STARTUP_TIMEOUT="300"` (5min)

#### High-End Hardware (≥16GB RAM)
- Can safely use `./setup-env.sh start` for full environment
- Consider running multiple project environments simultaneously
- Default timeouts are usually sufficient

### Usage Examples

#### ZincSearch Integration
```bash
# Index documents
curl -X POST "http://localhost:4080/api/index/logs/_doc" \
  -H "Content-Type: application/json" \
  -u admin:admin \
  -d '{"timestamp": "2024-01-01T12:00:00Z", "message": "Application started"}'

# Search documents
curl -X POST "http://localhost:4080/api/logs/_search" \
  -H "Content-Type: application/json" \
  -u admin:admin \
  -d '{"query": {"match": {"message": "started"}}}'
```

#### Redpanda Streaming
```bash
# Produce messages
echo "test message" | docker exec -i redpanda rpk topic produce test-topic

# Consume messages
docker exec redpanda rpk topic consume test-topic --print-headers

# Use REST API
curl -X POST "http://localhost:8082/topics/test-topic" \
  -H "Content-Type: application/vnd.kafka.json.v2+json" \
  -d '{"records":[{"value":"test message"}]}'
```

#### Spark Job Submission
```bash
# Submit Python job
docker exec spark-master /opt/spark/bin/spark-submit \
  --master spark://spark-master:7077 \
  --py-files dependencies.zip \
  my_job.py

# Submit Scala/Java job
docker exec spark-master /opt/spark/bin/spark-submit \
  --master spark://spark-master:7077 \
  --class com.example.MyApp \
  my-app.jar
```

#### Dex OIDC Integration
```bash
# Get OIDC configuration
curl "http://localhost:5556/dex/.well-known/openid_configuration"

# Example application redirect
open "http://localhost:5556/dex/auth?client_id=example-app&redirect_uri=http://localhost:5555/auth/callback&response_type=code&scope=openid+email"
```

#### Postfix Email Testing
```bash
# Send test email via SMTP
echo -e "Subject: Test\n\nTest message" | \
  sendmail -S localhost:1587 recipient@example.com

# Check mail queue
docker exec postfix postqueue -p
```

### With Development Workflows
- **Service Discovery**: All services register with the shared network
- **Health Checks**: Each service provides status endpoints
- **Log Aggregation**: Centralized logging with `./setup-env.sh logs`
- **Hot Reloading**: Services support configuration updates
- **Development Mode**: Optimized settings for local development

## ⚙️ Advanced Configuration

### Custom Port Allocation
If you need custom ports to avoid conflicts with existing services:

```bash
# In your project's .env file
# Data services range: 9000-9099
MINIO_PORT="9010"
REDPANDA_KAFKA_PORT="9020"

# Web UI range: 8000-8099
DREMIO_HTTP_PORT="8050"
AIRFLOW_PORT="8060"
SPARK_MASTER_WEB_PORT="8070"

# API services range: 4000-4999
ZINCSEARCH_HTTP_PORT="4090"
DEX_HTTP_PORT="5560"

# Worker services range: 8200-8299
SPARK_WORKER_WEB_PORT_BASE="8250"
```

### Production Considerations
- **Security**: Change default passwords in production
- **Resources**: Adjust memory limits based on your workload
- **Networking**: Consider using custom network ranges for production
- **Persistence**: Use external volumes for production data
- **Monitoring**: Enable verbose logging for troubleshooting

### Troubleshooting Common Issues

#### Port Already in Use
```bash
# Check what's using a port
netstat -tulpn | grep :8080

# Or on Windows
netstat -an | findstr :8080

# Kill process using port (Linux/Mac)
sudo fuser -k 8080/tcp
```

#### Container Won't Start
```bash
# Check container logs
./env/minio.sh logs 50

# Check system resources
podman stats

# Restart individual service
./env/dremio.sh restart
```

#### Service Can't Connect to Another Service
```bash
# Verify network connectivity
podman network inspect ${PROJECT_NAME}-network

# Check if both containers are on same network
podman inspect container1 | grep NetworkMode
podman inspect container2 | grep NetworkMode
```

## 📋 Requirements

- **Podman**: Container runtime (v3.0+)
- **Bash**: Shell environment (v4.0+)
- **Curl**: For health checks
- **Git**: For template management (optional)
- **System Resources**:
  - **8GB+ RAM** recommended (minimum 4GB)
  - **2GB+ free disk space** for container images
  - **Available ports**: Ensure default port ranges are free

## 🤝 Contributing

1. Fork this repository
2. Create feature branch
3. Add your service modules in `env/`
4. Update `.env.example` with new configurations
5. Submit pull request

## 📄 License

MIT License - see LICENSE file for details# setup-podman-env
