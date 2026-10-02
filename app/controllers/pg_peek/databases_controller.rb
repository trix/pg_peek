class PgPeek::DatabasesController < PgPeek::ApplicationController
  OVERVIEW_ROWS = 5

  def index
    @databases = PgPeek::Database.all
    # Resolved once: each miss logs a warning, and the view needs the answer
    # twice -- to list what works and to explain what does not.
    @configured_databases = @databases.select(&:connection_configured?)
    @report = PgPeek::Reports::Databases.new(databases: @configured_databases)
  end

  # Root. The primary's overview is what nearly everyone came for; the list of
  # databases is one click away as a switcher.
  def home
    configured = PgPeek::Database.all.select(&:connection_configured?)
    landing = configured.find(&:primary) || configured.first

    redirect_to landing ? database_path(landing) : databases_path
  end

  def show
    @database = PgPeek::Database.find(params[:id]) or raise ActiveRecord::RecordNotFound, "Database not found"
    @pg_stat_statements = PgPeek::PgStatStatements.new(database: @database)
    @tables = PgPeek::Reports::Tables.new(database: @database)
    @vitals = @database.vitals
    @stats_reset_at = @pg_stat_statements.reset_at
    @sessions = PgPeek::Reports::Sessions.new(database: @database)
    @connection_summary = @database.connection_summary

    if @pg_stat_statements.usable?
      @endpoints = PgPeek::Reports::Endpoints.new(database: @database)
      @jobs = PgPeek::Reports::Jobs.new(database: @database)
      @queries = PgPeek::Reports::Queries.new(database: @database)
    end

    @attention = attention
  end

  private
    # Computed, not browsed: the things worth acting on, each linking to where
    # you would act.
    def attention
      items = []

      ratio = @vitals["cache_hit_ratio"]&.to_f
      threshold = PgPeek.config.cache_hit_warning_threshold
      if ratio && ratio < threshold
        items << { text: "cache hit ratio #{ratio}% (below #{threshold}%)", href: nil }
      end

      @database.tables_with_dead_tuples(PgPeek.config.dead_tuple_warning_threshold).each do |table|
        vacuumed = table["last_autovacuum"] ? "last autovacuum #{helpers.time_ago_in_words(table["last_autovacuum"])} ago" : "never autovacuumed"
        items << { text: "#{table["relname"]}: #{table["dead_ratio"]}% dead tuples, #{vacuumed}",
                   href: database_table_path(@database, table["relname"]) }
      end

      # Scan counts restart at zero on a statistics reset, so right after one
      # every index looks unused. Small ones cost too little to act on; the
      # indexes page still lists them all.
      reset_at = @database.stats_reset_at
      if reset_at.nil? || reset_at < PgPeek.config.unused_index_min_stats_age.ago
        unused = PgPeek::Reports::Indexes.new(database: @database).unused
                   .select { |row| row["size_bytes"].to_i >= PgPeek.config.unused_index_min_size }
        if unused.any?
          bytes = unused.sum { |row| row["size_bytes"].to_i }
          items << { text: "#{helpers.pluralize(unused.size, "unused index")} · #{helpers.number_to_human_size(bytes)}",
                     href: database_indexes_path(@database) }
        end
      end

      activity = database_activity_path(@database)

      if @sessions.blocked.any?
        items << { text: "#{helpers.pluralize(@sessions.blocked.size, "session")} waiting for a lock", href: activity }
      end

      seconds = PgPeek.config.long_query_warning_seconds
      long_running = @sessions.long_running(seconds * 1000)
      if long_running.any?
        items << { text: "#{helpers.pluralize(long_running.size, "query")} running longer than #{seconds}s, longest #{helpers.format_duration_from_ms(long_running.first["duration_ms"])}",
                   href: activity }
      end

      seconds = PgPeek.config.idle_in_transaction_warning_seconds
      stale = @sessions.stale_transactions(seconds * 1000)
      if stale.any?
        items << { text: "#{helpers.pluralize(stale.size, "session")} idle in transaction for over #{seconds}s -- holding locks and blocking vacuum",
                   href: activity }
      end

      used = @connection_summary["client_connections"].to_i
      max = @connection_summary["max_connections"].to_i
      if max.positive? && used >= max * 0.8
        items << { text: "#{used} of #{max} connections in use", href: activity }
      end

      items
    end
end
