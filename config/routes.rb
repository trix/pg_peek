PgPeek::Engine.routes.draw do
  resources :pg_stat_statements, only: [ :index ] do
    collection do
      delete :reset
    end
  end

  root to: "pg_stat_statements#index"
end
