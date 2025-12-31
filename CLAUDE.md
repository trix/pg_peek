# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

pg_peek is a Rails Engine (gem) that provides a web UI for monitoring and analyzing PostgreSQL query performance. It's designed to be mounted into a Rails application for database introspection.

- **Framework:** Rails 8.1.1+ Engine with isolated namespace
- **Database:** PostgreSQL (uses pg_stat_statements extension)
- **Assets:** Pico CSS (classless CSS framework), Propshaft pipeline

## Common Commands

```bash
# Install dependencies
bundle install

# Run tests (uses dummy Rails app with SQLite)
rake test

# Run specific test file
ruby -Itest test/models/pg_peek/database_test.rb

# Start development server (dummy app)
cd test/dummy && rails s -p 3000

# Code style check
bin/rubocop

# Auto-fix style issues
bin/rubocop -A
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

### Routes

Routes are defined in `config/routes.rb` with databases as the primary resource and nested resources for tables and pg_stat_statements views.

## Testing

Tests use a dummy Rails app located in `test/dummy/` with SQLite3 (not PostgreSQL). The dummy app mounts the engine at `/pg_peek`.

## Development Notes

- Views use Pico CSS which is classless - semantic HTML elements are styled automatically
- The engine supports multiple database configurations (primary/replica/tracking)
- SQLcommenter integration parses `/*key=value,...*/` format comments from queries
