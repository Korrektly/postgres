# syntax=docker/dockerfile:1
# PostgreSQL with pre-built extension packages for fast multi-arch builds

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
ARG PG_TOKENIZER_VERSION=0.1.1

LABEL org.korrektly.pgvector.version="${PGVECTOR_VERSION}" \
    org.korrektly.timescaledb.version="${TIMESCALEDB_VERSION}" \
    org.korrektly.vectorchord.version="${VECTORCHORD_VERSION}" \
    org.korrektly.vectorchord-bm25.version="${VECTORCHORD_BM25_VERSION}" \
    org.korrektly.pg_tokenizer.version="${PG_TOKENIZER_VERSION}"

################################################################################
# Install pre-built extension packages
# Uses dpkg --print-architecture for multi-arch support (amd64/arm64)
################################################################################

# Install dependencies and add TimescaleDB repository
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        wget \
        ca-certificates \
        curl \
        gnupg \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://packagecloud.io/timescale/timescaledb/gpgkey \
        | gpg --dearmor > /etc/apt/keyrings/timescale_timescaledb-archive-keyring.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/timescale_timescaledb-archive-keyring.gpg] https://packagecloud.io/timescale/timescaledb/debian/ trixie main" \
        > /etc/apt/sources.list.d/timescale_timescaledb.list \
    && apt-get update

# Download TensorChord extension packages from GitHub Releases
RUN ARCH=$(dpkg --print-architecture) \
    && wget -q -P /tmp \
        https://github.com/tensorchord/VectorChord/releases/download/${VECTORCHORD_VERSION}/postgresql-18-vchord_${VECTORCHORD_VERSION}-1_${ARCH}.deb \
        https://github.com/tensorchord/VectorChord-bm25/releases/download/${VECTORCHORD_BM25_VERSION}/postgresql-18-vchord-bm25_${VECTORCHORD_BM25_VERSION}-1_${ARCH}.deb \
        https://github.com/tensorchord/pg_tokenizer.rs/releases/download/${PG_TOKENIZER_VERSION}/postgresql-18-pg-tokenizer_${PG_TOKENIZER_VERSION}-1_${ARCH}.deb

# Install all extensions
RUN ARCH=$(dpkg --print-architecture) \
    && apt-get install -y --no-install-recommends \
        postgresql-18-pgvector=${PGVECTOR_VERSION}-* \
        timescaledb-2-postgresql-18=${TIMESCALEDB_VERSION}~debian13-1800 \
        /tmp/postgresql-18-vchord_${VECTORCHORD_VERSION}-1_${ARCH}.deb \
        /tmp/postgresql-18-pg-tokenizer_${PG_TOKENIZER_VERSION}-1_${ARCH}.deb \
        /tmp/postgresql-18-vchord-bm25_${VECTORCHORD_BM25_VERSION}-1_${ARCH}.deb

# Clean up to minimize image size
RUN apt-get remove -y wget ca-certificates curl gnupg \
    && apt-get purge -y --auto-remove \
    && rm -rf \
        /tmp/* \
        /var/lib/apt/lists/* \
        /etc/apt/sources.list.d/timescale_timescaledb.list \
        /etc/apt/keyrings/timescale_timescaledb-archive-keyring.gpg

################################################################################
# Configure PostgreSQL to preload all extensions
################################################################################
RUN echo "shared_preload_libraries = 'timescaledb,vchord,vchord_bm25,vector,pg_tokenizer'" \
        >> /usr/share/postgresql/postgresql.conf.sample \
    && echo "search_path = '\"\$user\", public, bm25_catalog, tokenizer_catalog'" \
        >> /usr/share/postgresql/postgresql.conf.sample

# Copy initialization script and set permissions
COPY --chmod=0755 docker/init-extensions.sh /docker-entrypoint-initdb.d/10-init-extensions.sh

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD pg_isready -U postgres || exit 1
