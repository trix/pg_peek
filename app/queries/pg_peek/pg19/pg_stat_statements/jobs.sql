SELECT
  substring(query from 'job=''([^'']+)''') AS job_class,
  SUM(calls) AS total_calls,
  SUM(total_exec_time) AS total_exec_time_ms,
  COUNT(*) AS query_count
FROM pg_stat_statements
WHERE userid = (SELECT usesysid FROM pg_user WHERE usename = current_user LIMIT 1)
  AND dbid = (SELECT oid FROM pg_database WHERE datname = current_database())
  AND query NOT LIKE '%/* pg_peek */%'
  AND query ~ 'job=''[^'']+'''
GROUP BY job_class
ORDER BY total_exec_time_ms DESC
