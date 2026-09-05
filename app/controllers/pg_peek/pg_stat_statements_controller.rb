# Manages the extension itself. What it records is read by QueriesController,
# EndpointsController and JobsController.
class PgPeek::PgStatStatementsController < PgPeek::ApplicationController
  def reset
    @database = PgPeek::Database.find(params[:database_id]) or raise ActiveRecord::RecordNotFound, "Database not found"
    PgPeek::PgStatStatements.new(database: @database).reset!

    redirect_to database_path(@database, anchor: "pg_stat_statements"),
                notice: "pg_stat_statements has been reset."
  end
end
