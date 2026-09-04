module PgPeek
  class Configuration
    DEFAULT_EXCLUDED_TABLES = %w[schema_migrations ar_internal_metadata].freeze
    DEFAULT_DEAD_TUPLE_WARNING_THRESHOLD = 10 # percentage
    DEFAULT_OUTLIERS_LIMIT = 20
    DEFAULT_CACHE_HIT_WARNING_THRESHOLD = 99 # percentage

    attr_accessor :connections, :excluded_tables, :dead_tuple_warning_threshold, :outliers_limit,
                  :cache_hit_warning_threshold, :public_dashboard
    attr_writer :username, :password

    def initialize
      @connections = {}
      @excluded_tables = DEFAULT_EXCLUDED_TABLES.dup
      @dead_tuple_warning_threshold = DEFAULT_DEAD_TUPLE_WARNING_THRESHOLD
      @outliers_limit = DEFAULT_OUTLIERS_LIMIT
      @cache_hit_warning_threshold = DEFAULT_CACHE_HIT_WARNING_THRESHOLD
      @public_dashboard = false
    end

    def username
      @username.presence || credential(:username) || ENV["PG_PEEK_USERNAME"].presence
    end

    def password
      @password.presence || credential(:password) || ENV["PG_PEEK_PASSWORD"].presence
    end

    def credentials?
      username.present? && password.present?
    end

    # Reading credentials raises when the application has none set up at all,
    # which is not a configuration error for anyone using the ENV variables.
    def credential(key)
      Rails.application.try(:credentials)&.dig(:pg_peek, key).presence
    rescue StandardError
      nil
    end

    def connection_class_for(database_name)
      class_name = @connections[database_name]
      unless class_name
        Rails.logger.warn "[PgPeek] No connection configured for database '#{database_name}'. " \
                          "Add it to config.pg_peek.connections"
        return nil
      end
      class_name.constantize
    rescue NameError => e
      Rails.logger.warn "[PgPeek] Could not find connection class '#{class_name}': #{e.message}"
      nil
    end
  end
end
