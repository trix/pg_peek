class PgPeek::DatabasesController < PgPeek::ApplicationController
  def index
    @databases = PgPeek::Database.all
  end

  def show
    @database = PgPeek::Database.find(params[:id])
    @pg_stat_statements = PgPeek::PgStatStatements.new(database: @database)
    @table_stats = PgPeek::Table.inline_stats_for(@database, @database.tables)
  end
end
