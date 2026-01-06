# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

pg_peek is a Rails Engine (gem) that provides a web UI for monitoring and analyzing PostgreSQL query performance. It's designed to be mounted into a Rails application for database introspection.

- **Framework:** Rails 8.1.1+ Engine with isolated namespace
- **Database:** PostgreSQL (uses pg_stat_statements extension)
- **Assets:** Pico CSS (classless CSS framework), Propshaft pipeline

### Testing Against Other PostgreSQL Versions

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

The engine is mounted at `/pg_peek` and follows Rails conventions with namespaced components under `PgPeek::`.

### Key Models

- **`Database`** (`app/models/pg_peek/database.rb`): Abstracts PostgreSQL database connections. Enumerates configured databases from `ActiveRecord::Base.configurations`, retrieves version/extensions/tables, handles multiple database connections (primary, replica, etc.).

- **`PgStatStatements`** (`app/models/pg_peek/pg_stat_statements.rb`): Wraps the PostgreSQL `pg_stat_statements` extension. Checks installation status, installs/upgrades the extension, fetches outliers (slowest queries), resets statistics.

### Controllers

- **`DatabasesController`**: Lists databases, shows details (version, extensions), displays tables
- **`PgStatStatementsController`**: Analyzes slow queries with SQLcommenter tag extraction, resets statistics

### Helpers

`ApplicationHelper` provides SQLcommenter parsing utilities:
- `strip_sqlcommenter(sql)` - Removes SQL comments
- `extract_comment(sql)` - Extracts key=value pairs from comments
- `sqlcommenter_to_hash(comment)` - Parses SQLcommenter format

### URL structure

everything is database prefixed, `/pg_peek/databases/:database_id`
prefer GET requests (shareable links), so it easy to share links to specific databases with team members

### Routes

Routes are defined in `config/routes.rb` with databases as the primary resource and nested resources for tables and pg_stat_statements views.

## Testing

Tests use a dummy Rails app located in `test/dummy/` with PostgreSQL. The dummy app mounts the engine at `/pg_peek`.
Uses Minitest and database fixtures. 

## Development Notes

- Views use Pico CSS which is classless - semantic HTML elements are styled automatically
- The engine supports multiple database configurations (primary/replica/tracking)
- SQLcommenter integration parses `/*key=value,...*/` format comments from queries
