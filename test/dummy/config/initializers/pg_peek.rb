Rails.application.config.pg_peek.tap do |config|
  config.connections = {
    "primary" => "ApplicationRecord",
    "queue" => "SolidQueue::Record",
    "analytics" => "AnalyticsRecord"
  }
end
