module PgPeek
  class Configuration
    VALID_STATS_PROVIDERS = %i[pg_stat_statements pg_stat_monitor].freeze

    attr_reader :stats_provider
    attr_accessor :connections

    def initialize
      @stats_provider = :pg_stat_statements
      @connections = {}
    end

    def stats_provider=(value)
      value = value.to_sym
      if VALID_STATS_PROVIDERS.include?(value)
        @stats_provider = value
      else
        Rails.logger.warn "[PgPeek] Invalid stats_provider '#{value}'. " \
                          "Valid options: #{VALID_STATS_PROVIDERS.join(', ')}. " \
                          "Falling back to :pg_stat_statements"
        @stats_provider = :pg_stat_statements
      end
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
