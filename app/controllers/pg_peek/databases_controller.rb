class PgPeek::DatabasesController < PgPeek::ApplicationController
  def index
    @databases = PgPeek::Database.all
  end

  def show
    @database = PgPeek::Database.find(params[:id])
  end

  def tables
    @database = PgPeek::Database.find(params[:database_id])
  end
end
