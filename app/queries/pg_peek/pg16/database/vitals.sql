-- One row of health figures for the current database.
SELECT
  round(100.0 * blks_hit / NULLIF(blks_hit + blks_read, 0), 1) AS cache_hit_ratio,
  numbackends AS connections,
  xact_commit,
  xact_rollback,
  deadlocks,
  temp_files
FROM pg_stat_database
WHERE datname = current_database()
