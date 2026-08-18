#!/bin/sh
set -eu

psql --set=ON_ERROR_STOP=1 \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" \
  --set=replication_password="$POSTGRES_REPLICATION_PASSWORD" <<'SQL'
SELECT format(
  'CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD %L',
  :'replication_password'
)
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'replicator') \gexec

ALTER ROLE replicator WITH REPLICATION LOGIN PASSWORD :'replication_password';

CREATE TABLE IF NOT EXISTS events (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  event_type TEXT NOT NULL,
  payload JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
SQL

printf '%s\n' 'host replication replicator all scram-sha-256' >> "$PGDATA/pg_hba.conf"

