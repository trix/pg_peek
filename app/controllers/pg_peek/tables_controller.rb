class PgPeek::TablesController < PgPeek::ApplicationController
  before_action :set_database

  def index
    @tables = PgPeek::Reports::Tables.new(database: @database)
  end

  def show
    @table = @database.find_table(params[:name]) or raise ActiveRecord::RecordNotFound, "Table '#{params[:name]}' not found"
  end

  private
    def set_database
      @database = PgPeek::Database.find(params[:database_id]) or raise ActiveRecord::RecordNotFound, "Database not found"
    end
end
