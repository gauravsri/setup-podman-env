# Modular Podman Environment Setup

A reusable, modular environment setup system for managing containerized development environments with Podman. Designed for easy configuration and cross-project portability.

## 🚀 Quick Start

```bash
# Clone or copy this repository
git clone <this-repo> setup-podman-env
cd setup-podman-env

# Configure for your project
cp env/.env.example env/.env
# Edit env/.env with your project-specific settings

# Start basic stack (MinIO + Dremio)
./setup-env.sh basic

# Or start full stack (includes Airflow)
./setup-env.sh full
```

## 📦 Components

### Core Services
- **MinIO**: S3-compatible object storage
- **Dremio**: SQL federation engine with Delta Lake support
- **Airflow**: Workflow orchestration (optional)

### Memory Usage
- **Basic Setup**: ~1.3GB (MinIO + Dremio)
- **Full Stack**: ~2.3GB (MinIO + Dremio + Airflow)

## 🎯 Commands

### Main Commands
```bash
./setup-env.sh basic     # Start MinIO + Dremio
./setup-env.sh full      # Start full stack with Airflow
./setup-env.sh status    # Show current status
./setup-env.sh logs      # Show logs (all services)
./setup-env.sh logs minio # Show specific service logs
./setup-env.sh stop      # Stop all services
```

### Individual Service Control
```bash
./env/minio.sh {start|stop|restart|logs}
./env/dremio.sh {start|stop|restart|logs}
./env/airflow.sh {start|stop|restart|logs|create-dag}
```

## ⚙️ Configuration

### Environment Setup
1. Copy the example configuration:
   ```bash
   cp env/.env.example env/.env
   ```

2. Customize for your project:
   ```bash
   # Project Configuration
   PROJECT_NAME="my-awesome-project"
   PROJECT_DESCRIPTION="My Awesome Project"

   # Ports (avoid conflicts)
   MINIO_PORT="9000"
   MINIO_CONSOLE_PORT="9001"
   DREMIO_HTTP_PORT="8080"
   AIRFLOW_PORT="8090"

   # Resources (adjust for your hardware)
   MINIO_MEMORY="256m"
   DREMIO_MEMORY="1g"
   AIRFLOW_MEMORY="1g"
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

### MinIO (S3-Compatible Storage)
- **Purpose**: Object storage for data files
- **Web Console**: http://localhost:9001
- **Default Credentials**: minioadmin/minioadmin
- **Data Persistence**: Named volume `minio-data`

### Dremio (SQL Federation Engine)
- **Purpose**: SQL queries across data sources
- **Web UI**: http://localhost:8080
- **JDBC**: `jdbc:dremio:direct=localhost:9047`
- **Features**: Delta Lake support, query optimization
- **Data Persistence**: Named volume `dremio-data`

### Airflow (Workflow Orchestration)
- **Purpose**: DAG-based workflow management
- **Web UI**: http://localhost:8090
- **Default Credentials**: admin/admin
- **Features**: Python operators, scheduler, REST API
- **DAG Location**: `./airflow-local/dags/`

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
1. Copy this repository to your project
2. Customize `env/.env` with your project settings
3. Start the environment: `./setup-env.sh basic`
4. Develop your data pipelines
5. Use individual service scripts for troubleshooting

### For Existing Projects
1. Add this as a git submodule or copy files
2. Update your existing scripts to use these components
3. Migrate container configurations to `.env` format

### Troubleshooting
```bash
# Check service status
./setup-env.sh status

# View logs for all services
./setup-env.sh logs

# View logs for specific service
./env/dremio.sh logs 50    # Last 50 lines

# Restart problematic service
./env/minio.sh restart
```

## 🔍 Monitoring & Logs

### Service URLs
- **MinIO Console**: http://localhost:9001
- **Dremio Web UI**: http://localhost:8080
- **Airflow Web UI**: http://localhost:8090

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

### With Data Pipelines
- Use MinIO for storing input/output data
- Query data through Dremio SQL interface
- Orchestrate pipelines with Airflow DAGs

### With CI/CD
- Start environment in CI: `./setup-env.sh basic`
- Run tests against Dremio endpoints
- Stop environment: `./setup-env.sh stop`

### With Development
- Hot-reload DAGs in `airflow-local/dags/`
- Use individual service restart for quick iterations
- Monitor logs during development

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
