#!/bin/sh

set -e

echo "Waiting for ${DB_POSTGRESDB_HOST}:${DB_POSTGRESDB_PORT}..."
attempts=0

# -U is required: runAsUser=1000 isn't in postgres:16-alpine's /etc/passwd, so
# pg_isready can't getpwuid() a default and bails with "no attempt" before
# opening a socket. The value isn't authenticated, just sent in the startup
# packet.
until pg_isready -h "${DB_POSTGRESDB_HOST}" -p "${DB_POSTGRESDB_PORT}" -U postgres -t 3; do
  attempts=$((attempts + 1))
  if [ "$attempts" -ge 60 ]; then
    echo "Postgres not ready after 5 minutes; giving up"
    exit 1
  fi
  sleep 5
done

echo "Postgres is ready"
