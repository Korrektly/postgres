# syntax=docker/dockerfile:1
# Optimized multi-stage build for PostgreSQL with extensions
# This Dockerfile uses BuildKit mount caches and optimized layer ordering for fast builds

################################################################################
# Stage 1: Build stage - compile all extensions
################################################################################
FROM postgres:18.1-trixie AS builder

# Build arguments for versions
ARG PGVECTOR_VERSION=0.8.1
ARG TIMESCALEDB_VERSION=2.23.1
ARG VECTORCHORD_VERSION=1.0.0
ARG VECTORCHORD_BM25_VERSION=0.2.2

# Install ALL dependencies in a single layer for better caching
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    cmake \
    postgresql-server-dev-18 \
    libssl-dev \
    curl \
    ca-certificates \
    pkg-config \
    libpq-dev \
    clang \
    && rm -rf /var/lib/apt/lists/*

################################################################################
# Install Rust toolchain (cached layer)
################################################################################
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile minimal

################################################################################
# Build pgvector (lightweight C extension, builds fast)
################################################################################
RUN cd /tmp && \
    git clone --branch v${PGVECTOR_VERSION} --depth 1 https://github.com/pgvector/pgvector.git && \
    cd pgvector && \
    make clean && \
    make OPTFLAGS="" && \
    make install && \
    cd / && \
    rm -rf /tmp/pgvector

################################################################################
# Build TimescaleDB (CMake-based, moderate build time)
################################################################################
RUN cd /tmp && \
    git clone --branch ${TIMESCALEDB_VERSION} --depth 1 https://github.com/timescale/timescaledb.git && \
    cd timescaledb && \
    ./bootstrap -DREGRESS_CHECKS=OFF -DPROJECT_INSTALL_METHOD="docker" -DCMAKE_BUILD_TYPE=Release && \
    cd build && \
    make -j$(nproc) && \
    make install && \
    cd / && \
    rm -rf /tmp/timescaledb

################################################################################
# Install cargo-pgrx (one-time installation, heavily cached)
################################################################################
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/usr/local/cargo/git \
    cargo install cargo-pgrx --locked && \
    cargo pgrx init --pg18 /usr/bin/pg_config

################################################################################
# Build VectorChord with mount caches
# The mount caches persist cargo registry, git repos, and build artifacts
# This provides similar benefits to cargo-chef but works with pgrx projects
################################################################################
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/usr/local/cargo/git \
    --mount=type=cache,target=/tmp/cargo-build-cache \
    cd /tmp && \
    git clone --branch ${VECTORCHORD_VERSION} --depth 1 https://github.com/tensorchord/VectorChord.git && \
    cd VectorChord && \
    CARGO_TARGET_DIR=/tmp/cargo-build-cache/vchord cargo pgrx install --pg-config /usr/bin/pg_config --release && \
    cd / && \
    rm -rf /tmp/VectorChord

################################################################################
# Build VectorChord-bm25 with mount caches
################################################################################
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/usr/local/cargo/git \
    --mount=type=cache,target=/tmp/cargo-build-cache \
    cd /tmp && \
    git clone --branch ${VECTORCHORD_BM25_VERSION} --depth 1 https://github.com/tensorchord/VectorChord-bm25.git && \
    cd VectorChord-bm25 && \
    CARGO_TARGET_DIR=/tmp/cargo-build-cache/vchord-bm25 cargo pgrx install --pg-config /usr/bin/pg_config --release && \
    cd / && \
    rm -rf /tmp/VectorChord-bm25

################################################################################
# Stage 2: Final runtime image (minimal, production-ready)
################################################################################
FROM postgres:18.1-trixie

# Metadata labels (OCI spec)
LABEL org.opencontainers.image.title="Korrektly Postgres" \
    org.opencontainers.image.description="PostgreSQL 18 with pgvector, TimescaleDB, VectorChord, and VectorChord-bm25 for AI/ML workloads" \
    org.opencontainers.image.vendor="Korrektly" \
    org.opencontainers.image.source="https://github.com/Korrektly/postgres" \
    org.opencontainers.image.url="https://github.com/Korrektly/postgres" \
    org.opencontainers.image.documentation="https://github.com/Korrektly/postgres/blob/main/README.md" \
    org.opencontainers.image.licenses="AGPLv3" \
    maintainer="Korrektly Team"

# Version labels
ARG PGVECTOR_VERSION=0.8.1
ARG TIMESCALEDB_VERSION=2.23.1
ARG VECTORCHORD_VERSION=1.0.0
ARG VECTORCHORD_BM25_VERSION=0.2.2

LABEL org.korrektly.pgvector.version="${PGVECTOR_VERSION}" \
    org.korrektly.timescaledb.version="${TIMESCALEDB_VERSION}" \
    org.korrektly.vectorchord.version="${VECTORCHORD_VERSION}" \
    org.korrektly.vectorchord-bm25.version="${VECTORCHORD_BM25_VERSION}"

# Copy only the compiled extensions from builder
COPY --from=builder /usr/share/postgresql/18/extension/*.control /usr/share/postgresql/18/extension/
COPY --from=builder /usr/share/postgresql/18/extension/*.sql /usr/share/postgresql/18/extension/
COPY --from=builder /usr/lib/postgresql/18/lib/*.so /usr/lib/postgresql/18/lib/

# Configure PostgreSQL to preload TimescaleDB and VectorChord
RUN echo "shared_preload_libraries = 'timescaledb,vchord'" >> /usr/share/postgresql/postgresql.conf.sample

# Copy initialization script and set permissions
COPY --chmod=0755 docker/init-extensions.sh /docker-entrypoint-initdb.d/10-init-extensions.sh

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD pg_isready -U postgres || exit 1
