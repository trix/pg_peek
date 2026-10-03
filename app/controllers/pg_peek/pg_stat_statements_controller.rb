# Manages the extension itself. What it records is read by QueriesController,
# EndpointsController and JobsController.
class PgPeek::PgStatStatementsController < PgPeek::ApplicationController
  before_action :set_database

  def show
    return render "pg_peek/pg_stat_statements/not_preloaded" unless @pg_stat_statements.usable?

    @connection_summary = @database.connection_summary
  end

  def reset
    if @pg_stat_statements.resettable?
      @pg_stat_statements.reset!
      flash[:notice] = "pg_stat_statements has been reset."
    else
      flash[:alert] = "This role may not reset pg_stat_statements; the statistics were left as they are."
    end

    redirect_to database_pg_stat_statements_path(@database)
  end

  private
    def set_database
      @database = PgPeek::Database.find(params[:database_id]) or raise ActiveRecord::RecordNotFound, "Database not found"
      @pg_stat_statements = PgPeek::PgStatStatements.new(database: @database)
    end
end
