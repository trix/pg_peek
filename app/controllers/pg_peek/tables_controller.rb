class PgPeek::TablesController < PgPeek::ApplicationController
  def show
    @database = PgPeek::Database.find(params[:database_id]) or raise ActiveRecord::RecordNotFound, "Database not found"
    @table = @database.find_table(params[:name]) or raise ActiveRecord::RecordNotFound, "Table '#{params[:name]}' not found"
  end
end
