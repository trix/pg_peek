# PgPeek configuration
# See https://github.com/tiramizoo/pg_peek for more information.

Rails.application.config.pg_peek.tap do |config|
  # Stats provider for query analysis.
  # Options: :pg_stat_statements (default), :pg_stat_monitor
  # config.stats_provider = :pg_stat_statements
end
