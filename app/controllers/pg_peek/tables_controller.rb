class PgPeek::TablesController < ApplicationController
  def show
    @database = PgPeekDatabase.find(params[:database_id]) or raise ActiveRecord::RecordNotFound, "Database not found"

    @table = PgPeek::Table.new(@database, params[:name])
    raise ActiveRecord::RecordNotFound, "Table '#{params[:name]}' not found" unless @table.exists?
  end
end
