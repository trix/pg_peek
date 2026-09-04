class PgPeek::IndexesController < PgPeek::ApplicationController
  def index
    @database = PgPeek::Database.find(params[:database_id]) or raise ActiveRecord::RecordNotFound, "Database not found"
    @report = PgPeek::Reports::Indexes.new(database: @database)
    @stats_reset_at = @database.stats_reset_at
  end
end
