-- Client sessions on the current database, except the one asking. Every
-- duration is taken from one clock reading, so they agree with each other;
-- clock_timestamp() rather than now() because the reader may be inside a
-- long transaction of its own.
SELECT
  pid,
  usename,
  application_name,
  client_addr::text AS client_addr,
  state,
  wait_event_type,
  wait_event,
  backend_start,
  xact_start,
  query_start,
  state_change,
  round(1000 * EXTRACT(EPOCH FROM (clock_timestamp() - query_start)))::bigint AS query_ms,
  round(1000 * EXTRACT(EPOCH FROM (clock_timestamp() - xact_start)))::bigint AS xact_ms,
  round(1000 * EXTRACT(EPOCH FROM (clock_timestamp() - state_change)))::bigint AS state_ms,
  array_to_string(pg_blocking_pids(pid), ',') AS blocked_by,
  query
FROM pg_stat_activity
WHERE datname = current_database()
  AND backend_type = 'client backend'
  AND pid <> pg_backend_pid()
ORDER BY pid
