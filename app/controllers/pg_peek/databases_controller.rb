class PgPeek::DatabasesController < PgPeek::ApplicationController
  def index
    @databases = PgPeek::Database.all
  end

  def show
    @database = PgPeek::Database.find(params[:id])
  end
end
