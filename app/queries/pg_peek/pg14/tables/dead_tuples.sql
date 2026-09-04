-- Tables whose dead-tuple share is at or above the warning threshold.
SELECT
  relname,
  n_live_tup,
  n_dead_tup,
  round(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 1) AS dead_ratio,
  last_autovacuum
FROM pg_stat_user_tables
WHERE n_live_tup + n_dead_tup > 0
  AND 100.0 * n_dead_tup / (n_live_tup + n_dead_tup) >= {{threshold}}
ORDER BY dead_ratio DESC
