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

Then run the installer, which mounts the engine at `/pg_peek` and creates the
initializer:

```bash
bin/rails generate pg_peek:install
```

Pass `--skip-routes` if you would rather mount the engine yourself, for example
inside an authenticated scope.

Now map each database in your `database.yml` to the ActiveRecord class that
connects to it:

```ruby
# config/initializers/pg_peek.rb
Rails.application.config.pg_peek.tap do |config|
  config.connections = {
    "primary" => "ApplicationRecord"
  }
end
```

This step is required. A database without an entry cannot be opened and is not
listed.

Visit `/pg_peek` in your application to access the dashboard.

> [!WARNING]
> PgPeek has no authentication of its own. Anyone who can reach the route can
> read your schema, every normalized query in the database, and reset query
> statistics. Mount it behind your application's existing authentication before
> deploying it anywhere reachable:
>
> ```ruby
> authenticate :user, ->(user) { user.admin? } do
>   mount PgPeek::Engine, at: "/pg_peek"
> end
> ```

### Enabling pg_stat_statements

To enable query performance monitoring, run the generator to create a migration:

```bash
# For primary database
bin/rails generate pg_peek:pg_stat_statements

# For a secondary database (e.g., "analytics")
bin/rails generate pg_peek:pg_stat_statements --db analytics
```

Then run the migration:

```bash
bin/rails db:migrate
```

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
bin/rails db:setup
bin/rails s 

# Start the development server
rails s

# Visit http://localhost:3000/pg_peek
```

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

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
