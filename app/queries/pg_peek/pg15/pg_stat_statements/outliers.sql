SELECT
  interval '1 millisecond' * total_exec_time AS total_exec_time,
  COALESCE(to_char((total_exec_time/NULLIF(sum(total_exec_time) OVER(), 0)) * 100, 'FM990D0'), '0') || '%' AS prop_exec_time,
  to_char(calls, 'FM999G999G999G990') AS ncalls,
  ROUND(total_exec_time/NULLIF(calls, 0)) AS avg_exec_ms,
  interval '1 millisecond' * (blk_read_time + blk_write_time) AS sync_io_time,
  query
FROM pg_stat_statements
WHERE userid = (SELECT usesysid FROM pg_user WHERE usename = current_user LIMIT 1)
  AND dbid = (SELECT oid FROM pg_database WHERE datname = current_database())
ORDER BY total_exec_time DESC
LIMIT {{limit}}
