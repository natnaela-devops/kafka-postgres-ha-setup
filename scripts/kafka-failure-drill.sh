#!/usr/bin/env bash
set -Eeuo pipefail

compose=(docker compose)
marker="broker-failure-$(date +%s%N)"

cleanup() {
  "${compose[@]}" start kafka-1 >/dev/null 2>&1 || true
}
trap cleanup EXIT

"${compose[@]}" stop kafka-1
sleep 15

printf '%s\n' "{\"event_id\":\"$marker\",\"drill\":\"one-broker-down\"}" | \
  "${compose[@]}" exec -T kafka-2 /opt/kafka/bin/kafka-console-producer.sh \
    --bootstrap-server kafka-2:19092 \
    --topic banking-events

consumed=$("${compose[@]}" exec -T kafka-3 /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server kafka-3:19092 \
  --topic banking-events \
  --from-beginning \
  --max-messages 100 \
  --timeout-ms 15000 2>/dev/null || true)
grep -q "$marker" <<<"$consumed"

printf '%s\n' "PASS: produce and consume succeeded with kafka-1 stopped."

