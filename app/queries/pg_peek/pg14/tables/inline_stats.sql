SELECT
  t.relname AS table_name,
  s.heap_blks_read,
  s.heap_blks_hit,
  s.idx_blks_read,
  s.idx_blks_hit
FROM pg_stat_user_tables t
LEFT JOIN pg_statio_user_tables s ON t.relid = s.relid
WHERE t.relname IN ({{placeholders:count}})
