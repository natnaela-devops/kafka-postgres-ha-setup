#!/bin/sh
set -eu

if [ "$(id -u)" = "0" ]; then
  mkdir -p "$PGDATA"
  chown -R postgres:postgres "$PGDATA"
  exec gosu postgres "$0" "$@"
fi

if [ ! -s "$PGDATA/PG_VERSION" ]; then
  rm -rf "${PGDATA:?}"/*

  until PGPASSWORD="$POSTGRES_PASSWORD" pg_isready \
    --host=postgres-primary \
    --username="$POSTGRES_USER" \
    --dbname="$POSTGRES_DB" >/dev/null 2>&1; do
    sleep 2
  done

  PGPASSWORD="$POSTGRES_REPLICATION_PASSWORD" pg_basebackup \
    --host=postgres-primary \
    --username=replicator \
    --pgdata="$PGDATA" \
    --format=plain \
    --wal-method=stream \
    --write-recovery-conf \
    --create-slot \
    --slot=standby_1 \
    --progress

  chmod 0700 "$PGDATA"
fi

exec postgres -c hot_standby=on -c hot_standby_feedback=on

