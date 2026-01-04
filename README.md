# PgPeek

A Rails Engine that provides a web UI for monitoring and analyzing PostgreSQL query performance. Mount it into your Rails application for easy database introspection and slow query analysis.

![PgPeek Logo](app/assets/images/pg_peek/logo.png)

## Features

- **Database Overview**: View PostgreSQL version, installed extensions, and table listings
- **Query Performance Analysis**: Identify slow queries using the `pg_stat_statements` extension
- **SQLcommenter Support**: Parses and displays SQLcommenter tags from queries
- **Multi-Database Support**: Works with multiple database configurations (primary, replica, etc.)

## Installation

Add this line to your application's Gemfile:

```ruby
gem "pg_peek"
```

And then execute:

```bash
bundle install
```

Mount the engine in your `config/routes.rb`:

```ruby
mount PgPeek::Engine, at: "/pg_peek"
```

Visit `/pg_peek` in your application to access the dashboard.

### Requirements

- Rails 8.1+
- PostgreSQL 14+ with `pg_stat_statements` extension (for query analysis features)
- Only officially supported PostgreSQL versions are supported

## Development

### Prerequisites

- Ruby (see `.ruby-version`)
- Docker and Docker Compose (for PostgreSQL)

### Setup

```bash
# Install dependencies
bundle install

# Start PostgreSQL 18 (default for development)
docker compose up postgres18 -d

# Setup the dummy app database
cd test/dummy
rails db:prepare

# Start the development server
rails s

# Visit http://localhost:3000/pg_peek
```

### Testing Against Other PostgreSQL Versions

```bash
# PostgreSQL 16
POSTGRES_PORT=5432 rails db:create db:migrate

# PostgreSQL 17
POSTGRES_PORT=5433 rails db:create db:migrate
```

## Testing

```bash
# Run the full test suite
bin/rails test

# Code style check
bin/rubocop
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
