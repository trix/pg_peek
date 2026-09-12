# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

pg_peek is a Rails Engine (gem) that provides a web UI for monitoring and analyzing PostgreSQL query performance. It's designed to be mounted into a Rails application for database introspection.

- **Framework:** Rails 7.1.0+ Engine with isolated namespace
- **Database:** PostgreSQL (uses pg_stat_statements extension)
- **Assets:** Custom classless stylesheet (`app/assets/stylesheets/pg_peek/application.css`), monospace/terminal-styled with light+dark themes; Propshaft pipeline

### Testing Against Other PostgreSQL Versions

The report SQL differs per major Postgres version (see Query Loading below), so the suite runs against all of them, each on its own docker-compose port.

```bash
# Run databases
docker compose up -d

# PostgreSQL 14
bin/test-pg14

# PostgreSQL 15
bin/test-pg15

# PostgreSQL 16
bin/test-pg16

# PostgreSQL 17
bin/test-pg17

# PostgreSQL 18
bin/test-pg18
```

## Testing

```bash
# Run the full test suite
bin/test

# Code style check
bin/rubocop
```

## Architecture

### Engine Structure

The engine is mounted at `/pg_peek` and follows Rails conventions with namespaced components under `PgPeek::`. `lib/generators/pg_peek/install/` (`bin/rails generate pg_peek:install`) mounts the engine in the host app's routes and copies a `config/initializers/pg_peek.rb`.

### Configuration

`PgPeek.config` (`lib/pg_peek/configuration.rb`, an instance held on `Rails.application.config.pg_peek`, set up by `lib/pg_peek/engine.rb`) holds everything a host app customizes:

- `connections` - maps a `database.yml` database name to the ActiveRecord base class connected to it (how `Database#connection` resolves a connection)
- `excluded_tables` - strings/regexps hidden from the tables report (defaults to `schema_migrations`, `ar_internal_metadata`)
- `outliers_limit`, `cache_hit_warning_threshold`, `dead_tuple_warning_threshold`, `long_query_warning_seconds`, `idle_in_transaction_warning_seconds` - thresholds behind the "attention" callouts and report limits
- `username` / `password` (also settable via `PG_PEEK_USERNAME`/`PG_PEEK_PASSWORD` or `credentials.pg_peek.*`) and `public_dashboard`

### Authentication

`PgPeek::ApplicationController#authenticate` (`app/controllers/pg_peek/application_controller.rb`) runs before every request: it lets everything through when `public_dashboard` is set, requires HTTP Basic when credentials are configured (in every environment, including a tunnelled dev server), otherwise allows local requests and renders `authentication_required` (403) everywhere else. There's no way to leave a non-local deployment unprotected by accident.

### Key Models

- **`Database`** (`app/models/pg_peek/database.rb`): Abstracts a configured PostgreSQL database. Enumerates databases from `ActiveRecord::Base.configurations`, resolves its connection via `PgPeek.config.connections`, reports version/extensions/tables/vitals, and finds its `server_peers` (other configured databases on the same host:port - relevant because production tends to give each database its own server while review apps put several on one cluster).

- **`Table`** (`app/models/pg_peek/table.rb`): Per-table statistics from `pg_stat_user_tables`/`pg_statio_user_tables` - cache hit ratios, scan counts, dead tuple ratio, vacuum/analyze history. `Table.inline_stats_for` batch-fetches cache ratios for the tables list in one round trip.

- **`PgStatStatements`** (`app/models/pg_peek/pg_stat_statements.rb`): Wraps the PostgreSQL `pg_stat_statements` extension. Checks installation status, installs/upgrades the extension, fetches outliers (slowest queries) and per-job/endpoint breakdowns, resets statistics.

- **`SqlComment`** (`app/models/pg_peek/sql_comment.rb`): Parses a query's trailing SQLcommenter comment (`/*controller='posts',action='index'*/`) into a tags hash (`.tags`) and reduces it to what issued the query (`.label`: a job name, or `controller#action`). The one parser both the Sessions report and the view layer use, rather than two that used to disagree.

### Reports

Every angle pg_peek offers - queries, endpoints, jobs, tables, indexes, sessions, the database list itself - is a `PgPeek::Report` subclass (`app/reports/pg_peek/`) rather than bespoke controller-plus-view code: a report declares its `column`s (`PgPeek::Column`: key, header, alignment, format) and a `fetch_rows` returning hashes keyed by column name, usually straight from a `.sql` file. The same declaration can drive the HTML table or, e.g., a terminal renderer.

Concrete reports: `Databases`, `Tables`, `Queries` (and `JobQueries < Queries`, scoped to one job class), `Endpoints`, `Jobs`, `Indexes`, `Sessions`, `Blocked` (sessions waiting on a lock, built from `Sessions` rather than a second `pg_stat_activity` snapshot).

`PgPeek::ReportHelper#format_cell` turns a `Report::Row` cell into markup based on its column's `format` (`:number`, `:duration_ms`, `:duration`, `:percent`, `:ratio`, `:sql`, `:intensity`); `:intensity` needs `report.max_for(column)` since it renders as a bar relative to the largest value in that column. A `:sql` cell also resolves its SQLcommenter tags via `PgPeek::SqlComment`: when there's a label, a link line underneath (a job's own `/jobs/:job_class` page, or the `/endpoints` list for a controller/action - there is no per-endpoint page to link into yet); either way, every raw tag sits behind a `<details>` disclosure for the full dump.

### Query Loading

Raw SQL lives under `app/queries/pg_peek/pgNN/**/*.sql`, one directory per major Postgres version (14-18), loaded by `PgPeek::QueryLoader` (`lib/pg_peek/query_loader.rb`) using `database.major_version`. Reports and models call `QueryLoader.load("indexes/all", pg_version: ...)` rather than embedding SQL inline. New Postgres-version-specific behavior means adding a query file per version, not branching Ruby.

### Controllers

- **`DatabasesController`**: Lists databases (`index`), redirects to the primary's overview (`home`, the engine root), shows the per-database overview - vitals, attention, endpoints/jobs/queries sections (`show`)
- **`TablesController`**: Per-table detail page (stats, cache ratios)
- **`QueriesController`**: Slowest statements from pg_stat_statements
- **`EndpointsController`, `JobsController`**: Statements grouped by SQLcommenter controller/action and job tags (`JobsController#show` drills into one job's query shapes)
- **`IndexesController`, `ActivityController`**: Index usage; live sessions and lock waits
- **`PgStatStatementsController`**: Resets the extension's statistics

### Helpers

- **`ApplicationHelper`**: `strip_sqlcommenter` (removes the trailing comment before displaying SQL) and `sqlcommenter_href` (where a parsed tags hash points, via `PgPeek::SqlComment`) plus display formatting used across views - `format_duration`/`format_duration_from_ms` (unit auto-scales: `210ms`, `1.20s`, `2m 05s`), `format_rate`, `format_number`, `format_percentage`, `format_time_ago`, `intensity_bar`, `switch_database_path` (where the current section lives when switching databases).
- **`ReportHelper`**: Renders `Report`/`Column` cells (`format_cell`, `cell_class`) - see Reports above.

### URL structure

everything is database prefixed, `/pg_peek/databases/:database_id`
prefer GET requests (shareable links), so it easy to share links to specific databases with team members

### Routes

Routes are defined in `config/routes.rb` with databases as the primary resource and nested resources for tables, queries, endpoints, indexes, jobs, activity, and a `pg_stat_statements` reset action.

## Testing

Tests use a dummy Rails app located in `test/dummy/` with PostgreSQL, mounting the engine at `/pg_peek` and defining `Post`/`PostView` models plus jobs (`PostAnalyticsJob`, `PostEngagementJob`, etc.) that generate realistic multi-database, SQLcommenter-tagged query traffic. `test/dummy/db/seeds.rb` seeds posts/views and runs those jobs - useful for populating pg_stat_statements when running the dummy app manually in a browser.

Uses Minitest. `test_helper.rb` wires up fixture loading, but the suite mostly exercises live Postgres state instead: `open_pg_session` opens extra `pg` connections (so activity/lock tests can see sessions other than their own), `wait_for` polls `pg_stat_activity` after clearing its snapshot, and `skip_unless_usable`/`install_pg_stat_statements` handle servers where the extension isn't preloaded.

## Development Notes

- Views use a custom classless stylesheet - semantic HTML elements are styled automatically, monospace/tabular throughout, with light and dark themes
- The engine supports multiple database configurations, each mapped to an ActiveRecord class via `PgPeek.config.connections` (see Configuration above)
- SQLcommenter integration parses `/*key=value,...*/` format comments from queries
- `bin/rails generate pg_peek:install` is how a host app sets this up (initializer + route mount) - reach for it instead of hand-writing the mount/initializer
