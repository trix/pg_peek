-- Every index on a user table, with how often it has been scanned since the
-- statistics were last reset. Constraint indexes are marked so a zero scan
-- count is not mistaken for waste: they earn their keep on writes.
SELECT
  s.relname AS table_name,
  s.indexrelname AS index_name,
  s.idx_scan AS scans,
  s.idx_tup_read AS tuples_read,
  pg_relation_size(s.indexrelid) AS size_bytes,
  pg_size_pretty(pg_relation_size(s.indexrelid)) AS size,
  i.indisprimary AS primary_key,
  i.indisunique AS unique_index,
  pg_get_indexdef(s.indexrelid) AS definition
FROM pg_stat_user_indexes s
JOIN pg_index i ON i.indexrelid = s.indexrelid
WHERE s.schemaname = ANY (current_schemas(false))
ORDER BY pg_relation_size(s.indexrelid) DESC, s.relname, s.indexrelname
