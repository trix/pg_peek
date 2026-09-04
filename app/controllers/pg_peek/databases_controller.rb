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
    @stats_reset_at = stats_reset_at

    if @pg_stat_statements.usable?
      @endpoints = PgPeek::Reports::Endpoints.new(database: @database)
      @jobs = PgPeek::Reports::Jobs.new(database: @database)
      @queries = PgPeek::Reports::Queries.new(database: @database)
    end

    @attention = attention
  end

  private
    def stats_reset_at
      value = @pg_stat_statements.reset_at
      Time.zone.parse(value.to_s) if value.present?
    end

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

      if @stats_reset_at && @stats_reset_at > 1.hour.ago
        items << { text: "statistics were reset #{helpers.time_ago_in_words(@stats_reset_at)} ago -- figures may not be representative yet",
                   href: nil }
      end

      items
    end
end
