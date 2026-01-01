module PgPeek
  class TablesController < ApplicationController
    def show
      @database = Database.find(params[:database_id])
      raise ActiveRecord::RecordNotFound, "Database not found" unless @database

      @table = Table.new(@database, params[:name])
      raise ActiveRecord::RecordNotFound, "Table '#{params[:name]}' not found" unless @table.exists?
    end
  end
end
