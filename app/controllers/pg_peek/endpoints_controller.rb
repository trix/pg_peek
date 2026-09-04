class PgPeek::EndpointsController < PgPeek::ApplicationController
  def index
    @database = PgPeek::Database.find(params[:database_id])
    @pg_stat_statements = PgPeek::PgStatStatements.new(database: @database)

    return render "pg_peek/pg_stat_statements/not_preloaded" unless @pg_stat_statements.usable?

    @report = PgPeek::Reports::Endpoints.new(database: @database)
  end
end
