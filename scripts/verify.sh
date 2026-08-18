#!/usr/bin/env bash
set -Eeuo pipefail

compose=(docker compose)
db_user="${POSTGRES_USER:-app_user}"
db_name="${POSTGRES_DB:-banking_app}"

printf '%s\n' "Checking Kafka controller quorum..."
"${compose[@]}" exec -T kafka-1 /opt/kafka/bin/kafka-metadata-quorum.sh \
  --bootstrap-server kafka-1:19092 describe --status

topic_description=$("${compose[@]}" exec -T kafka-1 /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server kafka-1:19092 \
  --describe \
  --topic banking-events)
printf '%s\n' "$topic_description"
grep -q 'ReplicationFactor: 3' <<<"$topic_description"
grep -q 'min.insync.replicas=2' <<<"$topic_description"

marker="verification-$(date +%s%N)"
printf '%s\n' "{\"event_id\":\"$marker\",\"status\":\"accepted\"}" | \
  "${compose[@]}" exec -T kafka-2 /opt/kafka/bin/kafka-console-producer.sh \
    --bootstrap-server kafka-2:19092 \
    --topic banking-events

consumed=$("${compose[@]}" exec -T kafka-3 /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server kafka-3:19092 \
  --topic banking-events \
  --from-beginning \
  --max-messages 20 \
  --timeout-ms 15000 2>/dev/null || true)
grep -q "$marker" <<<"$consumed"

in_recovery=$("${compose[@]}" exec -T postgres-standby psql \
  --username="$db_user" \
  --dbname="$db_name" \
  --tuples-only \
  --no-align \
  --command='SELECT pg_is_in_recovery();')
[ "$in_recovery" = "t" ]

primary_count=$("${compose[@]}" exec -T postgres-primary psql \
  --username="$db_user" \
  --dbname="$db_name" \
  --tuples-only \
  --no-align \
  --command='SELECT count(*) FROM events;')

for _ in $(seq 1 20); do
  standby_count=$("${compose[@]}" exec -T postgres-standby psql \
    --username="$db_user" \
    --dbname="$db_name" \
    --tuples-only \
    --no-align \
    --command='SELECT count(*) FROM events;')
  if [ "$standby_count" = "$primary_count" ]; then
    printf '%s\n' "PASS: Kafka quorum/topic/message checks and PostgreSQL streaming replication checks succeeded."
    exit 0
  fi
  sleep 1
done

printf '%s\n' "FAIL: PostgreSQL standby did not catch up to the primary." >&2
exit 1

