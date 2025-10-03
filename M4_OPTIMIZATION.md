# M4 MacBook Pro Optimization Guide

## Hardware Specifications
- **Model**: MacBook Pro (Mac16,1) with Apple M4 chip
- **CPU**: 10 cores (4 performance + 6 efficiency)
- **GPU**: 10-core Apple M4 integrated
- **Memory**: 16 GB LPDDR5
- **Storage**: 512 GB SSD (180 GB free)
- **OS**: macOS 26.0.1 (Darwin 25.0.0)

## Resource Allocation Strategy

### Memory Distribution (16GB total)
| Component | Allocation | Usage |
|-----------|-----------|--------|
| macOS System | 4 GB | Reserved for OS |
| Available for Containers | 12 GB | Maximum usable |
| **Container Breakdown** | | |
| MinIO | 512 MB | S3-compatible storage |
| HBase | 2 GB | NoSQL database |
| Spark Master | 2 GB | Cluster coordinator |
| Spark Worker 1 | 4 GB | Processing worker |
| Spark Worker 2 | 4 GB | Processing worker |
| **Total Container Usage** | **12.5 GB** | Leaves 3.5GB for macOS |

### CPU Core Distribution (10 cores total)
| Component | Allocation | Cores Used |
|-----------|-----------|------------|
| macOS System | Reserved | 2 cores (efficiency) |
| Spark Master | Limited | 2 cores |
| Spark Worker 1 | Limited | 4 cores (performance) |
| Spark Worker 2 | Limited | 4 cores (shared with Worker 1) |
| **Total Container CPUs** | **8 cores** | Leaves 2 for system |

## Configuration Profiles

### Profile 1: M4 Optimized (Recommended)
Use the `.env.m4-macbook` configuration:
```bash
cp env/.env.m4-macbook env/.env
```

**Best for**: HBase to Delta conversion workloads on M4 MacBook Pro

**Services**: MinIO, Spark (2 workers), HBase

**Memory**: ~12.5GB total

### Profile 2: Lightweight Development
Modify `.env.m4-macbook` and reduce Spark workers:
```bash
SPARK_WORKER_COUNT="1"
SPARK_WORKER_MEMORY="4g"
```

**Best for**: Testing and development

**Memory**: ~8.5GB total

### Profile 3: Local Spark Only
For running Spark jobs without cluster:
```bash
# Don't start Spark cluster containers
# Use local[8] mode in spark-submit
spark-submit --master local[8] \
  --driver-memory 6g \
  --executor-memory 4g \
  --conf spark.local.dir=/tmp/spark-temp
```

**Best for**: Single-node Spark testing

**Memory**: ~8.5GB (Driver 6GB + MinIO 512MB + HBase 2GB)

## Optimization Settings Applied

### Spark Configuration
```properties
# Core settings
spark.master=local[8]                          # Use 8 cores
spark.driver.memory=6g                          # Driver memory
spark.executor.memory=4g                        # Executor memory
spark.sql.shuffle.partitions=16                 # 2x CPU cores

# Performance optimizations
spark.serializer=org.apache.spark.serializer.KryoSerializer
spark.sql.adaptive.enabled=true
spark.sql.adaptive.coalesce.partitions.enabled=true
spark.local.dir=/tmp/spark-temp                 # Use fast SSD

# Memory tuning
spark.memory.fraction=0.6                       # 60% for execution/storage
spark.memory.storageFraction=0.5                # 50/50 execution/storage split
```

### HBase Configuration
```bash
# Heap size optimized for 2GB container
HBASE_HEAPSIZE=1024                             # 1GB heap
HBASE_OFFHEAPSIZE=512                           # 512MB off-heap

# Region server settings
hbase.regionserver.handler.count=30             # Thread pool
hbase.regionserver.global.memstore.size=0.4     # 40% for memstore
```

### Container Resource Limits
```bash
# Spark Master
--memory=2g --cpus=2

# Spark Workers (each)
--memory=4g --cpus=4

# HBase
--memory=2g --cpus=2

# MinIO
--memory=512m --cpus=1
```

## Performance Tips

### 1. Dataset Size Recommendations
- **Small datasets** (<5GB): Use local[8] mode, no cluster needed
- **Medium datasets** (5-20GB): Use 2-worker cluster configuration
- **Large datasets** (>20GB): Consider running on actual cluster, not local

### 2. Podman/Docker Settings
```bash
# Increase Podman VM resources (if using Podman Desktop)
podman machine set --memory 12288 --cpus 8

# Or via Docker Desktop preferences:
# Memory: 12 GB
# CPUs: 8
# Swap: 2 GB
# Disk: Use remaining available space
```

### 3. macOS Optimizations
```bash
# Increase file descriptors
ulimit -n 10240

# Check current limits
ulimit -a

# Optimize SSD performance (already optimal on M4)
# - APFS with trim enabled (default)
# - Fast NVMe storage via Apple Fabric
```

### 4. Monitoring Resource Usage
```bash
# Monitor container resources
podman stats

# Monitor system resources
top -o cpu

# Monitor memory pressure
sudo memory_pressure

# Check disk I/O
sudo fs_usage -w | grep spark
```

## Troubleshooting

### Out of Memory Errors
```bash
# Reduce Spark worker memory
SPARK_WORKER_MEMORY="3g"
SPARK_WORKER_COUNT="1"

# Or use local mode with smaller driver
spark-submit --master local[4] --driver-memory 4g
```

### Slow Performance
```bash
# Increase shuffle partitions for larger datasets
--conf spark.sql.shuffle.partitions=32

# Enable compression
--conf spark.sql.parquet.compression.codec=snappy
--conf spark.sql.orc.compression.codec=snappy

# Use faster serialization
--conf spark.serializer=org.apache.spark.serializer.KryoSerializer
--conf spark.kryoserializer.buffer.max=512m
```

### Container Startup Issues
```bash
# Clean up stopped containers
podman container prune

# Remove unused volumes
podman volume prune

# Restart Podman machine (if using Podman Desktop)
podman machine stop
podman machine start
```

## Benchmarks (Expected Performance)

### HBase Snapshot Export
- **Small table** (1K rows): <1 minute
- **Medium table** (100K rows): 2-5 minutes
- **Large table** (1M rows): 10-20 minutes

### Spark Conversion to Delta
- **Small dataset** (<1GB): 1-2 minutes
- **Medium dataset** (5GB): 5-10 minutes
- **Large dataset** (20GB): 20-40 minutes

*Note: Times assume SSD storage and no I/O bottlenecks*

## Quick Start Commands

### 1. Setup Environment
```bash
cd /Users/gaurav/workspace/claude/hbase-delta-converter/setup-podman-env
cp env/.env.m4-macbook env/.env
```

### 2. Start Services
```bash
# Start full stack
./project-wrapper.sh start

# Or start individual services
./project-wrapper.sh start spark
./project-wrapper.sh start hbase
./project-wrapper.sh start minio
```

### 3. Run Conversion Job
```bash
cd /Users/gaurav/workspace/claude/hbase-delta-converter

# Export HBase snapshot
./scripts/export-hbase-snapshot.sh \
  -c config/user_table_export.properties \
  -e config/env/local.env

# Convert to Delta Lake
./scripts/convert-to-delta.sh \
  -c config/user_table_conversion_local.properties \
  -m local
```

### 4. Monitor Progress
```bash
# Spark UI
open http://localhost:8070

# HBase UI
open http://localhost:16010

# MinIO Console
open http://localhost:9001
```

### 5. Cleanup
```bash
# Stop all services
./project-wrapper.sh stop

# Remove all containers and volumes
podman system prune -a --volumes
```
