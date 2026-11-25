-- What the shared statements add up to, next to everything the database ran.
WITH statements AS (
  SELECT calls, total_exec_time, NOT ({{attributable}}) AS shared
  FROM pg_stat_statements
  WHERE userid = (SELECT usesysid FROM pg_user WHERE usename = current_user LIMIT 1)
    AND dbid = (SELECT oid FROM pg_database WHERE datname = current_database())
    AND query NOT LIKE '%/* pg_peek */%'
)
SELECT
  count(*) FILTER (WHERE shared) AS statement_count,
  COALESCE(sum(calls) FILTER (WHERE shared), 0) AS calls,
  COALESCE(sum(total_exec_time) FILTER (WHERE shared), 0) AS exec_time_ms,
  COALESCE(sum(total_exec_time), 0) AS all_exec_time_ms
FROM statements
