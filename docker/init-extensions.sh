#!/bin/bash
set -e

# This script is executed automatically by the postgres Docker image
# during the first initialization of the database

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Enable pgvector extension
    CREATE EXTENSION IF NOT EXISTS vector;

    -- Enable TimescaleDB extension
    CREATE EXTENSION IF NOT EXISTS timescaledb;

    -- Enable VectorChord extension
    CREATE EXTENSION IF NOT EXISTS vchord;

    -- Enable VectorChord-bm25 extension
    CREATE EXTENSION IF NOT EXISTS vchord_bm25;

    -- Enable pg_tokenizer extension
    CREATE EXTENSION IF NOT EXISTS pg_tokenizer;

    -- Display installed extensions
    \dx
EOSQL

echo "PostgreSQL extensions (pgvector, TimescaleDB, VectorChord, VectorChord-bm25, and pg_tokenizer) have been successfully installed and enabled."
