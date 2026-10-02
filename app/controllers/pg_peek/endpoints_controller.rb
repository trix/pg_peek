class PgPeek::EndpointsController < PgPeek::ApplicationController
  before_action :set_database

  def index
    return render "pg_peek/pg_stat_statements/not_preloaded" unless @pg_stat_statements.usable?

    @report = PgPeek::Reports::Endpoints.new(database: @database)
  end

  def show
    @endpoint = "#{params[:endpoint_controller]}##{params[:endpoint_action]}"
    return render "pg_peek/pg_stat_statements/not_preloaded" unless @pg_stat_statements.usable?

    @report = PgPeek::Reports::EndpointQueries.new(database: @database, endpoint: @endpoint)
  end

  private
    def set_database
      @database = PgPeek::Database.find(params[:database_id])
      @pg_stat_statements = PgPeek::PgStatStatements.new(database: @database)
    end
end
