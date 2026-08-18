#!/usr/bin/env bash
set -Eeuo pipefail

compose=(docker compose)

"${compose[@]}" exec -T kafka-1 /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server kafka-1:19092 \
  --create \
  --if-not-exists \
  --topic banking-events \
  --partitions 3 \
  --replication-factor 3 \
  --config min.insync.replicas=2

"${compose[@]}" exec -T postgres-primary psql \
  --username="${POSTGRES_USER:-app_user}" \
  --dbname="${POSTGRES_DB:-banking_app}" \
  --set=ON_ERROR_STOP=1 \
  --command="INSERT INTO events (event_type, payload) SELECT 'lab_bootstrap', '{\"source\":\"bootstrap\"}'::jsonb WHERE NOT EXISTS (SELECT 1 FROM events WHERE event_type = 'lab_bootstrap');"

printf '%s\n' "Lab resources are initialized. Run ./scripts/verify.sh next."

