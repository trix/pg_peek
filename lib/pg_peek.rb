require "pg_peek/version"
require "pg_peek/configuration"
require "pg_peek/engine"

module PgPeek
  def self.config
    Rails.application.config.pg_peek
  end
end
