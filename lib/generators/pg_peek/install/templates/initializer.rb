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

  # Maximum number of outlier queries to display.
  # config.outliers_limit = 20

  # Dead tuple ratio threshold (percentage) for warnings.
  # config.dead_tuple_warning_threshold = 10

  # Index scan counts start from zero when statistics are reset, so right
  # after a reset every index looks unused. The overview waits this long
  # before calling unused indexes out.
  # config.unused_index_min_stats_age = 1.day

  # A query running longer than this is called out on the overview.
  # config.long_query_warning_seconds = 5

  # A session idle in transaction longer than this holds locks and blocks
  # vacuum, and is called out on the overview.
  # config.idle_in_transaction_warning_seconds = 60
end
