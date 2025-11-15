# Korrektly Postgres

A production-ready PostgreSQL 18 Docker image optimized for AI/ML workloads, featuring advanced vector search, full-text search, and time-series capabilities.

[![Docker](https://img.shields.io/badge/docker-ghcr.io-blue)](https://github.com/Korrektly/postgres/pkgs/container/postgres)
[![PostgreSQL](https://img.shields.io/badge/postgresql-18-blue)](https://www.postgresql.org/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

## Features

This specialized PostgreSQL image includes the following pre-installed extensions:

| Extension            | Version | Description                                                                  |
| -------------------- | ------- | ---------------------------------------------------------------------------- |
| **pgvector**         | 0.8.1   | Vector similarity search and embedding storage for AI/ML applications        |
| **TimescaleDB**      | 2.23.1  | Time-series database optimization with compression and continuous aggregates |
| **VectorChord**      | 1.0.0   | High-performance vector search with HSW (Hierarchical Small World) algorithm |
| **VectorChord-bm25** | 0.2.2   | Full-text search using BM25 ranking algorithm                                |

### Use Cases

- **AI/ML Applications**: Store and search vector embeddings for semantic search, RAG systems, and recommendation engines
- **Time-Series Analytics**: Efficient storage and querying of time-series data with automatic compression
- **Hybrid Search**: Combine vector similarity search with traditional full-text search
- **Real-time Applications**: High-performance queries for latency-sensitive workloads

## Quick Start

### Using Docker

```bash
# Pull the latest image
docker pull ghcr.io/korrektly/postgres:latest

# Run with default settings
docker run -d \
  --name korrektly-postgres \
  -e POSTGRES_PASSWORD=your_secure_password \
  -p 5432:5432 \
  ghcr.io/korrektly/postgres:latest
```

### Using Docker Compose

```yaml
version: '3.8'

services:
  postgres:
    image: ghcr.io/korrektly/postgres:latest
    container_name: korrektly-postgres
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: your_secure_password
      POSTGRES_DB: korrektly
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/18/docker
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  postgres_data:
```

Then run:

```bash
docker-compose up -d
```

## Environment Variables

| Variable            | Default                         | Description                              |
| ------------------- | ------------------------------- | ---------------------------------------- |
| `POSTGRES_USER`     | `postgres`                      | PostgreSQL superuser name                |
| `POSTGRES_PASSWORD` | -                               | PostgreSQL superuser password (required) |
| `POSTGRES_DB`       | `postgres`                      | Default database name                    |
| `PGDATA`            | `/var/lib/postgresql/18/docker` | PostgreSQL data directory                |

## Architecture

### Multi-Stage Build

The Docker image uses a multi-stage build process:

1. **Builder Stage**: Compiles all extensions from source with optimized build flags
2. **Final Stage**: Minimal runtime image with only necessary binaries

This approach results in a smaller final image size while maintaining all functionality.

### Preloaded Libraries

The following libraries are preloaded for optimal performance:
- `timescaledb`
- `vchord`

These are configured via `shared_preload_libraries` in PostgreSQL configuration.

## Building from Source

### Prerequisites

- Docker 20.10+
- Docker Buildx (for multi-platform builds)

### Local Build

```bash
# Clone the repository
git clone https://github.com/Korrektly/postgres.git
cd postgres

# Build the image
docker build -t korrektly-postgres .

# Run locally
docker run -d \
  --name postgres-test \
  -e POSTGRES_PASSWORD=test123 \
  -p 5432:5432 \
  korrektly-postgres
```

### Multi-Platform Build

```bash
# Create buildx builder
docker buildx create --name multiarch --use

# Build for multiple platforms
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t ghcr.io/korrektly/postgres:latest \
  .
```

## Development

### Running Tests

```bash
# Start the container
docker-compose up -d

# Connect to PostgreSQL
docker exec -it korrektly-postgres psql -U postgres

# Verify extensions
\dx

# Run extension tests
SELECT * FROM pg_extension;
```

### Adding Custom Extensions

1. Modify [Dockerfile](Dockerfile) to add build steps for your extension
2. Update [docker/init-extensions.sh](docker/init-extensions.sh) to enable the extension on startup
3. Rebuild the image

## Health Checks

The image includes a built-in health check using `pg_isready`:

- **Interval**: 30 seconds
- **Timeout**: 10 seconds
- **Retries**: 3

You can check container health:

```bash
docker inspect --format='{{.State.Health.Status}}' korrektly-postgres
```

## Performance Tuning

### Recommended PostgreSQL Settings

For production workloads, consider tuning these settings in `postgresql.conf`:

```conf
# Memory
shared_buffers = 4GB
effective_cache_size = 12GB
work_mem = 64MB
maintenance_work_mem = 1GB

# Connections
max_connections = 200

# Vector Search Optimization
ivfflat.probes = 10

# TimescaleDB
timescaledb.max_background_workers = 8
```

Mount custom configuration:

```bash
docker run -d \
  -v ./postgresql.conf:/etc/postgresql/postgresql.conf \
  ghcr.io/korrektly/postgres:latest \
  -c config_file=/etc/postgresql/postgresql.conf
```

## Security

### Best Practices

1. **Never use default passwords** in production
2. **Use secrets management** for sensitive credentials
3. **Enable SSL/TLS** for connections
4. **Limit network exposure** using Docker networks
5. **Regular updates** - rebuild images to get latest security patches

### Example with Docker Secrets

```yaml
version: '3.8'

services:
  postgres:
    image: ghcr.io/korrektly/postgres:latest
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/postgres_password
    secrets:
      - postgres_password

secrets:
  postgres_password:
    file: ./secrets/postgres_password.txt
```

## Platform Support

This image is built for the following platforms:

- `linux/amd64` (x86_64)
- `linux/arm64` (ARM64/Apple Silicon)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

## Version History

See [Releases](https://github.com/Korrektly/postgres/releases) for version history and changelogs.

## License

This project is licensed under the AGPLv3 License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [PostgreSQL](https://www.postgresql.org/) - The world's most advanced open source database
- [pgvector](https://github.com/pgvector/pgvector) - Vector similarity search for Postgres
- [TimescaleDB](https://github.com/timescale/timescaledb) - Time-series database built on PostgreSQL
- [VectorChord](https://github.com/tensorchord/VectorChord) - High-performance vector search
- [VectorChord-bm25](https://github.com/tensorchord/VectorChord-bm25) - VectorChord-bm25 for full-text search

## Support

- **Issues**: [GitHub Issues](https://github.com/Korrektly/postgres/issues)
- **Discord**: [Korrektly Discord](https://discord.gg/zrbGmCZmuf)