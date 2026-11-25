-- Tables that autovacuum should have cleaned by now: more dead tuples than its
-- own trigger point (autovacuum_vacuum_threshold + scale_factor * live rows),
-- and a dead-tuple share at or above the warning threshold. Small tables never
-- reach the trigger point, so a high share alone is not a problem.
SELECT
  relname,
  n_live_tup,
  n_dead_tup,
  round(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 1) AS dead_ratio,
  last_autovacuum
FROM pg_stat_user_tables
WHERE n_dead_tup > current_setting('autovacuum_vacuum_threshold')::int
                   + current_setting('autovacuum_vacuum_scale_factor')::float * n_live_tup
  AND 100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0) >= {{threshold}}
ORDER BY dead_ratio DESC
