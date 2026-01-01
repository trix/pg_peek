# Cache Hit Ratio Feature Specification

## Overview

Add per-table cache hit ratio monitoring and comprehensive table health statistics to pg_peek. This feature introduces a new Table detail page accessible from the database tables listing.

## Data Model

### New Model: `PgPeek::Table`

Create `app/models/pg_peek/table.rb` that encapsulates all table statistics.

**Query Strategy:** Single joined query combining `pg_stat_user_tables` and `pg_statio_user_tables` for efficiency.

**Caching:** Use Ruby memoization (`@stats ||= ...`) to cache query results within the model instance.

**Source Views:**
- `pg_statio_user_tables` - cache statistics (heap, index, toast, toast_index block hits/reads)
- `pg_stat_user_tables` - row statistics, vacuum stats, scan counts
- `pg_class` - row estimate (`reltuples`)

### Cache Metrics (All Shown Separately)

| Metric | Source Columns | Display |
|--------|---------------|---------|
| Heap Cache Hit % | `heap_blks_hit`, `heap_blks_read` | Percentage, N/A if no reads |
| Index Cache Hit % | `idx_blks_hit`, `idx_blks_read` | Percentage, N/A if no reads |
| Toast Cache Hit % | `toast_blks_hit`, `toast_blks_read` | Percentage, N/A if no reads |
| Toast Index Cache Hit % | `tidx_blks_hit`, `tidx_blks_read` | Percentage, N/A if no reads |

**Index Stats:** Aggregated only (sum all indexes for the table). Do not show per-index breakdown.

**Zero Activity Handling:** Display "N/A" for tables with zero block reads.

### Row Statistics

| Metric | Source Column | Display Format |
|--------|--------------|----------------|
| Sequential Scans | `seq_scan` | Count + percentage of total scans |
| Index Scans | `idx_scan` | Count + percentage of total scans |
| Rows Fetched | `seq_tup_read + idx_tup_fetch` | Raw count + auto-scaled rate |
| Rows Inserted | `n_tup_ins` | Raw count + auto-scaled rate |
| Rows Updated | `n_tup_upd` | Raw count + auto-scaled rate |
| Rows Deleted | `n_tup_del` | Raw count + auto-scaled rate |
| Live Tuples | `n_live_tup` | Count |
| Dead Tuples | `n_dead_tup` | Count + ratio to live + guidance |
| Row Estimate | `reltuples` (pg_class) | Estimated count |

**Rate Calculations:**
- Calculate rates based on `stats_reset` timestamp from `pg_stat_bgwriter`
- Auto-scale unit selection: `/s`, `/min`, `/hr`, `/day` based on magnitude
- Display format: "1,234,567 (~500/hr)"

**Scan Percentage:** Show "Index usage: 82%" calculated as `idx_scan / (seq_scan + idx_scan) * 100`

### Vacuum/Maintenance Statistics

| Metric | Source Column | Display Format |
|--------|--------------|----------------|
| Last Vacuum | `last_vacuum` | Relative time ("3 hours ago") |
| Last Autovacuum | `last_autovacuum` | Relative time |
| Last Analyze | `last_analyze` | Relative time |
| Last Autoanalyze | `last_autoanalyze` | Relative time |
| Vacuum Count | `vacuum_count` | Count |
| Autovacuum Count | `autovacuum_count` | Count |
| Analyze Count | `analyze_count` | Count |
| Autoanalyze Count | `autoanalyze_count` | Count |

### Dead Tuple Guidance

Display "Consider running VACUUM" guidance when dead tuple ratio exceeds configurable threshold.

**Threshold Calculation:** `n_dead_tup / (n_live_tup + n_dead_tup) * 100`

**Configuration:**
```ruby
PgPeek.config.dead_tuple_warning_threshold = 10 # percentage, default 10%
```

## Configuration

### Table Exclusions

Support array with both strings and regex patterns:

```ruby
PgPeek.config.excluded_tables = [
  'schema_migrations',
  'ar_internal_metadata',
  /^_/,  # tables starting with underscore
  /^pg_/ # avoid confusion with system tables
]
```

**Default:** `['schema_migrations', 'ar_internal_metadata']`

### Dead Tuple Warning Threshold

```ruby
PgPeek.config.dead_tuple_warning_threshold = 10 # percentage
```

## Routes

Add nested table resource under databases:

```ruby
# config/routes.rb
resources :databases, only: [:index, :show] do
  resources :tables, only: [:show], param: :name
  # ... existing pg_stat_statements routes
end
```

**URL Structure:** `/databases/:database_id/tables/:name`

Table names with special characters will be URL-encoded.

## Controllers

### TablesController

Create `app/controllers/pg_peek/tables_controller.rb`:

```ruby
module PgPeek
  class TablesController < ApplicationController
    def show
      @database = Database.find(params[:database_id])
      @table = Table.new(@database, params[:name])
      raise ActiveRecord::RecordNotFound unless @table.exists?
    end
  end
end
```

**404 Handling:** Raise `ActiveRecord::RecordNotFound` for non-existent tables, let Rails handle with standard 404 page.

## Views

### Table Detail Page

**Path:** `app/views/pg_peek/tables/show.html.erb`

**Layout:** Three sections with headers

```
+--------------------------------------------------+
| Databases > primary > users          [Chart Icon] |
+--------------------------------------------------+
|                                                  |
| Cache Performance                                |
| ------------------------------------------------ |
| Heap Cache Hit:        98.5%                     |
| Index Cache Hit:       99.2%                     |
| Toast Cache Hit:       N/A                       |
| Toast Index Cache Hit: N/A                       |
|                                                  |
| Row Activity                                     |
| ------------------------------------------------ |
| Estimated Rows:        1,234,567                 |
| Sequential Scans:      1,234 (18%)               |
| Index Scans:           5,678 (82%)               |
| Index Usage:           82%                       |
| Rows Fetched:          9,876,543 (~1.2k/hr)      |
| Rows Inserted:         123,456 (~15/hr)          |
| Rows Updated:          234,567 (~28/hr)          |
| Rows Deleted:          12,345 (~1.5/hr)          |
| Live Tuples:           1,234,567                 |
| Dead Tuples:           12,345 (1.0% of live)     |
|                                                  |
| Maintenance                                      |
| ------------------------------------------------ |
| Last Vacuum:           3 hours ago               |
| Last Autovacuum:       1 day ago                 |
| Last Analyze:          3 hours ago               |
| Last Autoanalyze:      1 day ago                 |
| Vacuum Count:          42                        |
| Autovacuum Count:      156                       |
|                                                  |
| [View queries for this table →]                  |
+--------------------------------------------------+
```

**Breadcrumb Navigation:** Full clickable path "Databases > db_name > table_name"

**Missing Stats:** If table exists but has no stats entry, show all metrics as 0 or N/A with explanation.

**Visual Style:** Plain numbers following Pico CSS semantic approach (no color coding).

### Modified Database Show Page (Tables Listing)

Update `app/views/pg_peek/databases/show.html.erb`:

**Changes:**
1. Make table names clickable links to detail page
2. Add chart icon (fa-chart-line) next to each table name
3. Show inline stats: "H: 98% I: 95%" (Heap and Index cache hit %)

**Example Row:**
```
users [chart-icon]  H: 98% I: 95%
```

Both table name and chart icon link to `/databases/:db/tables/users`

## Cross-Linking: Query Filter

### Link to Filtered pg_stat_statements

Add "View queries for this table" link on table detail page that navigates to pg_stat_statements outliers with table filter applied.

**URL:** `/databases/:db/pg_stat_statements/outliers?table=users`

### Query Filtering Implementation

Use regex parsing to match table names in SQL queries:

```ruby
def queries_for_table(table_name)
  # Match table in FROM, JOIN, UPDATE, INSERT INTO, DELETE FROM clauses
  pattern = /\b(FROM|JOIN|UPDATE|INTO|DELETE\s+FROM)\s+["']?#{Regexp.escape(table_name)}["']?\b/i
  outliers.select { |q| q[:query].match?(pattern) }
end
```

**Trade-off:** Regex parsing may have edge cases with quoted identifiers, CTEs, or subqueries. Acceptable for this use case.

## Testing

Use PostgreSQL for all tests (dummy app uses PostgreSQL, not SQLite).

### Test Coverage Required

1. **Table Model Tests:**
   - Cache hit ratio calculations
   - Handling of zero-activity tables (N/A display)
   - Rate calculations with auto-scaling
   - Dead tuple ratio and warning threshold
   - Table existence check
   - Excluded tables filtering

2. **Controller Tests:**
   - Show action renders correctly
   - 404 for non-existent tables
   - URL encoding for special table names

3. **View Tests:**
   - All three sections render
   - Breadcrumb navigation
   - Cross-link to pg_stat_statements
   - Inline stats in tables list

4. **Integration Tests:**
   - Navigate from database show to table detail
   - Search filter still works with clickable tables
   - Query filtering by table name

## Implementation Notes

### SQL Query for Table Stats

```sql
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
```

### Cache Hit Ratio Formula

```ruby
def cache_hit_ratio(hits, reads)
  total = hits + reads
  return nil if total.zero?  # Display as N/A
  (hits.to_f / total * 100).round(1)
end
```

### Auto-Scaling Rate Unit

```ruby
def format_rate(count, seconds_elapsed)
  return "N/A" if seconds_elapsed.nil? || seconds_elapsed.zero?

  per_second = count.to_f / seconds_elapsed

  case per_second
  when 0...0.017      # < 1/min
    "#{(per_second * 86400).round(1)}/day"
  when 0.017...1      # < 1/sec
    "#{(per_second * 3600).round(1)}/hr"
  when 1...60         # < 60/sec
    "#{(per_second * 60).round(1)}/min"
  else
    "#{per_second.round(1)}/s"
  end
end
```

## Files to Create/Modify

### New Files
- `app/models/pg_peek/table.rb`
- `app/controllers/pg_peek/tables_controller.rb`
- `app/views/pg_peek/tables/show.html.erb`
- `test/models/pg_peek/table_test.rb`
- `test/controllers/pg_peek/tables_controller_test.rb`

### Modified Files
- `config/routes.rb` - add tables resource
- `lib/pg_peek/configuration.rb` - add excluded_tables, dead_tuple_warning_threshold
- `app/views/pg_peek/databases/show.html.erb` - clickable tables, icons, inline stats
- `app/helpers/pg_peek/application_helper.rb` - rate formatting, time ago helpers

## Summary of Decisions

| Decision | Choice |
|----------|--------|
| Cache layers shown | All separately (heap, index, toast, toast_index) |
| Granularity | Per-table only |
| Zero activity | Show as "N/A" |
| UI location | New table detail page |
| Stats reset | No reset button (read-only) |
| Additional metrics | Full dashboard (cache + rows + vacuum) |
| Visual style | Plain numbers |
| Navigation | Table name link + chart icon |
| Index stats | Aggregated only |
| Model architecture | New PgPeek::Table model |
| System tables | User tables only |
| Missing stats handling | Show zeros/N/A |
| Query strategy | Single joined query |
| URL structure | `/databases/:db/tables/:name` |
| pg_stat_statements link | Link to filtered view |
| Query filter method | Regex parsing |
| Table exclusions | Configurable with patterns |
| Time display | Relative only |
| Page layout | Sections with headers |
| Row counts | Raw counts + auto-scaled rates |
| 404 handling | Standard Rails 404 |
| Icon | fa-chart-line (chart/graph) |
| Exclusion config | Array of strings and regex |
| Scan display | Counts + percentage |
| Dead tuples | With guidance when threshold exceeded |
| Dead threshold | Configurable |
| Table size | Row estimate from reltuples |
| Breadcrumbs | Full clickable path |
| Tables list | Inline stats (H: % I: %) |
| Model caching | Memoize instance |
