class PgPeek::DatabasesController < PgPeek::ApplicationController
  def index
    @databases = PgPeek::Database.all
    # Resolved once: each miss logs a warning, and the view needs the answer
    # twice -- to list what works and to explain what does not.
    @configured_databases = @databases.select(&:connection_configured?)
  end

  def show
    @database = PgPeek::Database.find(params[:id])
    @pg_stat_statements = PgPeek::PgStatStatements.new(database: @database)
    @tables = PgPeek::Reports::Tables.new(database: @database)
  end
end
