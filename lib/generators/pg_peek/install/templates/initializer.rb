# PgPeek configuration
# See https://github.com/trix/pg_peek for more information.

Rails.application.config.pg_peek.tap do |config|
  # Authentication.
  #
  # Outside development and test, pg_peek refuses to serve until it knows how it
  # is protected. Give it credentials with PG_PEEK_USERNAME / PG_PEEK_PASSWORD or
  # a pg_peek: entry in credentials.yml.enc and it asks for them over HTTP basic.
  # Credentials, once set, apply in every environment -- including a development
  # server exposed through a tunnel.
  #
  # If you mount the engine behind your own authentication instead, say so:
  # config.public_dashboard = true

  # Database connections mapping.
  # Maps database names (from database.yml) to their ActiveRecord base class.
  config.connections = {
    "primary" => "ApplicationRecord"
  }

  # Tables to exclude from the tables list.
  # Supports strings and regular expressions.
  config.excluded_tables = %w[schema_migrations ar_internal_metadata]

  # Stats provider for query analysis.
  # Options: :pg_stat_statements (default), :pg_stat_monitor
  # config.stats_provider = :pg_stat_statements

  # Maximum number of outlier queries to display.
  # config.outliers_limit = 20

  # Dead tuple ratio threshold (percentage) for warnings.
  # config.dead_tuple_warning_threshold = 10
end
