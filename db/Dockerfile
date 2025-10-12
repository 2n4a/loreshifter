FROM postgres:16-alpine

ENV POSTGRES_USER=postgres
ENV POSTGRES_DB=loreshifter
ENV POSTGRES_INITDB_ARGS=--data-checksums
ENV POSTGRES_INITDB_WALDIR=/var/lib/postgresql/wal

RUN mkdir -p /var/lib/postgresql/wal && \
    chown -R postgres:postgres /var/lib/postgresql/wal && \
    chmod 700 /var/lib/postgresql/wal

COPY db/migrations /migrations
COPY db/migrate.sh /docker-entrypoint-initdb.d/

RUN chmod +x /docker-entrypoint-initdb.d/migrate.sh && \
    chown -R postgres:postgres /docker-entrypoint-initdb.d/

# Healthcheck configuration
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD pg_isready -U $POSTGRES_USER -d $POSTGRES_DB

RUN { \
    echo "max_connections = 100"; \
    echo "shared_buffers = 256MB"; \
    echo "work_mem = 8MB"; \
    echo "maintenance_work_mem = 64MB"; \
    echo "effective_cache_size = 768MB"; \
    echo "fsync = on"; \
    echo "synchronous_commit = on"; \
    echo "log_statement = 'none'"; \
    echo "log_duration = off"; \
    echo "log_min_duration_statement = 1000"; \
    echo "log_connections = on"; \
    echo "log_disconnections = on"; \
    echo "log_lock_waits = on"; \
    echo "log_temp_files = 0"; \
    echo "log_autovacuum_min_duration = 0"; \
    echo "track_io_timing = on"; \
    echo "track_activity_query_size = 2048"; \
    echo "idle_in_transaction_session_timeout = '10min'"; \
    echo "statement_timeout = '30s'"; \
    echo "lock_timeout = '30s'"; \
    echo "listen_addresses = '*'"; \
} > /usr/local/share/postgresql/postgresql.conf.sample

USER postgres

EXPOSE 5432