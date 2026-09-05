-- Server-wide connection use. max_connections is a cluster setting, so the
-- count spans every database. current_user is who pg_peek connects as, for
-- the hint about hidden query text.
SELECT
  current_setting('max_connections')::int AS max_connections,
  count(*) FILTER (WHERE backend_type = 'client backend') AS client_connections,
  current_user AS username
FROM pg_stat_activity
