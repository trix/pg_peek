# Manages the extension itself. What it records is read by QueriesController,
# EndpointsController and JobsController.
class PgPeek::PgStatStatementsController < PgPeek::ApplicationController
  def reset
    @database = PgPeek::Database.find(params[:database_id]) or raise ActiveRecord::RecordNotFound, "Database not found"
    pg_stat_statements = PgPeek::PgStatStatements.new(database: @database)

    if pg_stat_statements.resettable?
      pg_stat_statements.reset!
      flash[:notice] = "pg_stat_statements has been reset."
    else
      flash[:alert] = "This role may not reset pg_stat_statements; the statistics were left as they are."
    end

    redirect_to database_path(@database, anchor: "pg_stat_statements")
  end
end
