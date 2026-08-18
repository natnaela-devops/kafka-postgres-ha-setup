# Operations and failure-drill runbook

This runbook is for the local lab. It records repeatable checks and explains where orchestration stops.

## Routine health checks

```bash
docker compose ps
docker compose exec kafka-1 /opt/kafka/bin/kafka-metadata-quorum.sh --bootstrap-server kafka-1:19092 describe --status
docker compose exec kafka-1 /opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka-1:19092 --describe --topic banking-events
docker compose exec postgres-primary psql -U app_user -d banking_app -c 'TABLE pg_stat_replication;'
docker compose exec postgres-standby psql -U app_user -d banking_app -c 'SELECT pg_is_in_recovery();'
```

## Kafka one-broker failure

Run `make drill`. The script stops `kafka-1`, waits for leader election, and verifies produce/consume through the two remaining brokers. A trap restarts the broker even if the drill fails.

Expected result: the replicated topic remains available because its replication factor is three and minimum in-sync replicas is two. Losing a second broker removes the write quorum and is expected to reject durable writes.

## PostgreSQL standby promotion

The Compose lab implements streaming replication but deliberately does not pretend to provide automated database failover. To practice a controlled promotion:

1. Stop the primary: `docker compose stop postgres-primary`.
2. Confirm the standby is in recovery.
3. Promote it: `docker compose exec postgres-standby pg_ctl promote -D /var/lib/postgresql/data`.
4. Confirm `SELECT pg_is_in_recovery();` returns `false`.
5. Point a test client at port `5433` and run a write/read check.

Do not simply restart the old primary after promotion. It has a divergent timeline and must be rebuilt as a standby (for example with a fresh base backup or `pg_rewind`) before rejoining.

## Recovery objectives

No RPO or RTO number is claimed by this repository. Measure them during repeated drills, record the environment and dataset size, and only then publish a result. Asynchronous PostgreSQL streaming replication can lose transactions that were committed on the primary but not yet replayed on the standby.

## Reset

`make reset` deletes all lab volumes. This is intentionally destructive and should only be used for disposable local data.

