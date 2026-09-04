# PgPeek

A Rails Engine that provides a web UI for monitoring and analyzing PostgreSQL query performance. Mount it into your Rails application for easy database introspection and slow query analysis.

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

### Authentication

pg_peek exposes your schema, every normalized query in the database, and an
endpoint that resets query statistics. Outside development and test it refuses
to serve until you say how it is protected.

Give it credentials and it asks for them over HTTP basic:

```bash
PG_PEEK_USERNAME=peek PG_PEEK_PASSWORD=...
```

or equivalently in `config/credentials.yml.enc`:

```yaml
pg_peek:
  username: peek
  password: ...
```

Credentials, once set, apply in **every** environment — including a development
server exposed through a tunnel.

If you would rather mount the engine behind authentication you already have, say
so and pg_peek stays out of the way:

```ruby
# config/initializers/pg_peek.rb
config.public_dashboard = true
```

```ruby
# config/routes.rb
constraints ->(request) { request.session[:admin_id].present? } do
  mount PgPeek::Engine, at: "/pg_peek"
end
```

Development and test are exempt when no credentials are set, so local work is
never interrupted.

### Enabling pg_stat_statements

Query analysis needs the `pg_stat_statements` extension, and enabling it is two
separate steps on two different things. Doing only the first is the most common
way to end up with a dashboard that shows nothing.

**1. Load the module into the server.** This is PostgreSQL configuration, not
database state: a migration cannot do it, and it takes effect only after a
restart.

```sql
ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_statements';
```

or the equivalent line in `postgresql.conf`. Then restart PostgreSQL. On a
managed service this is usually a parameter-group setting; in Docker, pass
`-c shared_preload_libraries=pg_stat_statements` to the server command.

**2. Create the extension in each database.** The generator writes a one-line
migration (`enable_extension "pg_stat_statements"`) so this is tracked in your
schema and applied per environment:

```bash
# For primary database
bin/rails generate pg_peek:pg_stat_statements

# For a secondary database (e.g., "analytics")
bin/rails generate pg_peek:pg_stat_statements --db analytics

bin/rails db:migrate
```

If you do step 2 without step 1, the extension reports itself as installed but
its views cannot be queried. pg_peek detects this and shows the instructions
above in place of every page that needs statistics, so you will not be left
guessing — but you will be left waiting for a restart.

A restart also clears all collected statistics, so expect an empty dashboard
until your application has run for a while afterwards.

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
