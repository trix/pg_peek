PgPeek::Engine.routes.draw do
  resources :databases, only: [ :index, :show ] do
    resources :tables, only: [ :show ], param: :name
    resources :endpoints, only: [ :index ]
    resources :jobs, only: [ :index, :show ], param: :job_class

    resource :pg_stat_statements do
      delete :reset
      get :outliers

      root to: "pg_stat_statements#outliers"
    end
  end

  root to: "databases#index"
end
