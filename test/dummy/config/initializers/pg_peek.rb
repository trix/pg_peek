Rails.application.config.pg_peek.tap do |config|
  config.connections = {
    "primary" => "ApplicationRecord",
    # The same database, declared a replica, so there is one to look at.
    "primary_replica" => "ApplicationRecord",
    "queue" => "SolidQueue::Record",
    "analytics" => "AnalyticsRecord"
  }
end
