SELECT
  t.relname AS table_name,
  t.seq_scan,
  t.seq_tup_read,
  t.idx_scan,
  t.idx_tup_fetch,
  t.n_tup_ins,
  t.n_tup_upd,
  t.n_tup_del,
  t.n_live_tup,
  t.n_dead_tup,
  t.last_vacuum,
  t.last_autovacuum,
  t.last_analyze,
  t.last_autoanalyze,
  t.vacuum_count,
  t.autovacuum_count,
  t.analyze_count,
  t.autoanalyze_count,
  s.heap_blks_read,
  s.heap_blks_hit,
  s.idx_blks_read,
  s.idx_blks_hit,
  s.toast_blks_read,
  s.toast_blks_hit,
  s.tidx_blks_read,
  s.tidx_blks_hit,
  c.reltuples AS row_estimate
FROM pg_stat_user_tables t
LEFT JOIN pg_statio_user_tables s ON t.relid = s.relid
LEFT JOIN pg_class c ON t.relid = c.oid
WHERE t.relname = $1
