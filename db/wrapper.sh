#!/bin/bash
set -e
if [ -f /run/secrets/db-password ]; then
    cp /run/secrets/db-password /tmp/db-password
    chown postgres:postgres /tmp/db-password
    chmod 600 /tmp/db-password
    export POSTGRES_PASSWORD_FILE=/tmp/db-password
fi

exec docker-entrypoint.sh postgres