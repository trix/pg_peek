-- What each waiting session is waiting for. A backend waits for at most one
-- lock at a time, so pid identifies the row. Relations from other databases
-- render as a bare oid, which the caller filters out by pid anyway.
SELECT
  pid,
  locktype,
  mode,
  CASE WHEN relation IS NOT NULL THEN relation::regclass::text END AS relation
FROM pg_locks
WHERE NOT granted
  AND pid <> pg_backend_pid()
