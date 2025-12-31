module PgPeek
  class Configuration
    VALID_STATS_PROVIDERS = %i[pg_stat_statements pg_stat_monitor].freeze

    attr_reader :stats_provider

    def initialize
      @stats_provider = :pg_stat_statements
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
  end
end
