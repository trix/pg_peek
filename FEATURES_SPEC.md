# PgPeek Feature Proposals

Low-hanging-fruit features that provide maximum value insights for Rails developers using PostgreSQL.

## 1. Cache Hit Ratio

**Priority:** High
**Effort:** Low
**Value:** Instant indicator of database memory health

Shows how often data is served from memory vs disk. A ratio below 99% on production often indicates memory issues.

```sql
SELECT
  datname,
  round(100.0 * sum(blks_hit) / nullif(sum(blks_hit) + sum(blks_read), 0), 2) as cache_hit_ratio
FROM pg_stat_database
WHERE datname = current_database()
GROUP BY datname;
```

**UI:** Single prominent metric on database overview page with color coding (green >99%, yellow 95-99%, red <95%).

---

## 2. Table Sizes

**Priority:** High
**Effort:** Low
**Value:** Quickly identify bloated tables and index overhead

```sql
SELECT
  relname,
  pg_size_pretty(pg_total_relation_size(relid)) as total_size,
  pg_size_pretty(pg_relation_size(relid)) as table_size,
  pg_size_pretty(pg_indexes_size(relid)) as index_size,
  n_live_tup as row_count
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(relid) DESC;
```

**UI:** Sortable table with size columns, potentially a bar chart visualization.

---

## 3. Unused Indexes

**Priority:** High
**Effort:** Low
**Value:** Identifies wasted disk space and write overhead

Indexes that have never been used (idx_scan = 0) are candidates for removal.

```sql
SELECT
  schemaname,
  relname as table_name,
  indexrelname as index_name,
  idx_scan as times_used,
  pg_size_pretty(pg_relation_size(indexrelid)) as index_size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND indexrelname NOT LIKE '%_pkey'
ORDER BY pg_relation_size(indexrelid) DESC;
```

**UI:** Warning list of unused indexes with size impact. Exclude primary keys.

---

## 4. Table Health Dashboard

**Priority:** Medium
**Effort:** Medium
**Value:** Identifies tables needing vacuum/analyze

Shows sequential vs index scans, dead tuples, and last maintenance times.

```sql
SELECT
  relname,
  seq_scan,
  idx_scan,
  n_live_tup,
  n_dead_tup,
  round(100.0 * n_dead_tup / nullif(n_live_tup + n_dead_tup, 0), 2) as dead_tuple_pct,
  last_vacuum,
  last_autovacuum,
  last_analyze,
  last_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;
```

**UI:** Table with color-coded cells for dead tuple percentage and staleness of vacuum/analyze.

---

## 5. Active Connections & Long-Running Queries

**Priority:** Medium
**Effort:** Medium
**Value:** Real-time visibility into database activity

```sql
-- Connection summary
SELECT
  state,
  count(*) as count
FROM pg_stat_activity
WHERE datname = current_database()
GROUP BY state;

-- Long-running queries (>1 second)
SELECT
  pid,
  state,
  usename,
  application_name,
  query_start,
  now() - query_start as duration,
  wait_event_type,
  wait_event,
  left(query, 100) as query_preview
FROM pg_stat_activity
WHERE datname = current_database()
  AND state != 'idle'
  AND query_start < now() - interval '1 second'
ORDER BY query_start;
```

**UI:** Connection state pie chart + table of active queries with duration highlighting.

---

## 6. Missing Index Candidates

**Priority:** Medium
**Effort:** Low
**Value:** Identifies tables that may benefit from indexing

Tables with high sequential scan ratio may need better indexes.

```sql
SELECT
  relname,
  seq_scan,
  idx_scan,
  round(100.0 * seq_scan / nullif(seq_scan + idx_scan, 0), 2) as seq_scan_pct,
  n_live_tup as row_count
FROM pg_stat_user_tables
WHERE seq_scan > 1000
  AND n_live_tup > 10000
ORDER BY seq_scan DESC;
```

## 7. Other

Insights nobody else provides well:

1. Controller/Action DB Time - "UsersController#index consumes 45% of total DB time"
2. Job Performance - "ImportUsersJob generates 30% of all query time"
3. N+1 Heatmap - Same query with high call count from same action = likely N+1
4. Per-Action Query Distribution - Which actions generate most queries vs most time

-- Already have this data in pg_stat_statements.query:
-- SELECT * FROM users /*controller='users',action='index'*/

-- Could aggregate to show:
-- controller:action | total_time | calls | avg_time | queries
-- users#index       | 45.2%      | 12,340| 2.3ms    | 8 unique
-- jobs#ImportJob    | 23.1%      | 890   | 45ms     | 3 unique

This turns generic "slow queries" into "slow parts of YOUR app" - actionable for Rails devs.

Should I update the spec file with SQLcommenter-focused features instead?


**UI:** Warning list filtered to tables with >1000 seq scans and >10k rows where seq_scan_pct > 50%.

---

## Implementation Notes

### Model Pattern

Each feature should follow the existing pattern in `PgPeek::Database`:

```ruby
# app/models/pg_peek/database.rb
def cache_hit_ratio
  connection.select_value(<<~SQL)
    SELECT round(100.0 * sum(blks_hit) / nullif(sum(blks_hit) + sum(blks_read), 0), 2)
    FROM pg_stat_database WHERE datname = current_database()
  SQL
end
```

### View Pattern

Use existing Pico CSS styling (classless). Tables should use `data-controller="table-search"` for filtering.

### Route Pattern

Features can be added as:
- Methods on `DatabasesController#show` (simple metrics)
- New controller actions (complex features like active queries)
- Nested resources under databases (if CRUD needed)

### Testing

Mock PostgreSQL responses in tests since dummy app uses SQLite:

```ruby
test "cache_hit_ratio returns percentage" do
  PgPeek::Database.any_instance.stubs(:cache_hit_ratio).returns(99.5)
  # ...
end
```
