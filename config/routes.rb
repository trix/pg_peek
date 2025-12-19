PgPeek::Engine.routes.draw do
  resources :databases, only: [ :index, :show ] do
    resources :pg_stat_statements, only: [ :index ]
  end

  root to: "databases#index"
end
