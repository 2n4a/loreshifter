FROM postgres:16

ENV POSTGRES_USER=devuser
ENV POSTGRES_PASSWORD=devpass
ENV POSTGRES_DB=devdb

COPY db/migrations /migrations
COPY db/migrate.sh /docker-entrypoint-initdb.d/migrate.sh

RUN chmod +x /docker-entrypoint-initdb.d/migrate.sh
