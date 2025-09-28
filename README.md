# Modular Podman Environment Setup

A reusable, modular environment setup system for managing containerized development environments with Podman. Designed for easy configuration and cross-project portability.

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
# Option A: Copy template
cp -r setup-podman-env /path/to/your/project/

# Option B: Git submodule
git submodule add <template-repo-url> setup-podman-env

# 2. Create project-specific setup using project wrapper
# See project-wrapper.sh for common functions and patterns
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
- **Master UI**: http://localhost:8080 (configurable)
- **Master URL**: spark://localhost:7077
- **Features**: Batch processing, streaming, ML, graph processing
- **Configuration**: Configurable workers, memory, cores
- **Use Cases**: ETL pipelines, data science, machine learning

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

### Service URLs (default ports, configurable in .env)
- **MinIO Console**: http://localhost:9001
- **Dremio Web UI**: http://localhost:8080
- **Airflow Web UI**: http://localhost:8090
- **ZincSearch API**: http://localhost:4080
- **Redpanda Admin**: http://localhost:9644
- **Dex OIDC**: http://localhost:5556/dex
- **Spark Master UI**: http://localhost:8080 (may conflict with Dremio)
- **Postfix SMTP**: localhost:1587

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

## 📋 Requirements

- **Podman**: Container runtime
- **Bash**: Shell environment
- **Curl**: For health checks
- **System Resources**:
  - 8GB+ RAM recommended
  - 2GB+ free disk space

## 🤝 Contributing

1. Fork this repository
2. Create feature branch
3. Add your service modules in `env/`
4. Update `.env.example` with new configurations
5. Submit pull request

## 📄 License

MIT License - see LICENSE file for details# setup-podman-env
