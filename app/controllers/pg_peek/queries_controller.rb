# https://docs.percona.com/pg-stat-monitor/comparison.html
class PgPeek::QueriesController < PgPeek::ApplicationController
  def index
    @database = PgPeek::Database.find(params[:database_id]) or raise ActiveRecord::RecordNotFound, "Database not found"
    @pg_stat_statements = PgPeek::PgStatStatements.new(database: @database)

    # The extension can be installed while the module was never preloaded, in
    # which case querying its views raises instead of returning rows.
    return render "pg_peek/pg_stat_statements/not_preloaded" unless @pg_stat_statements.usable?

    @queries = PgPeek::Reports::Queries.new(database: @database)
  end
end
