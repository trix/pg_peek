PgPeek::Engine.routes.draw do
  resources :jobs, only: [ :index, :show ], param: :job_class

  resources :databases, only: [ :index, :show ] do
    resources :tables, only: [ :show ], param: :name

    resource :pg_stat_statements do
      delete :reset

      get :outliers
      get :by_controller_action
      get :by_job
      get :by_table_name

      root to: "pg_stat_statements#outliers"
    end
  end

  root to: "databases#index"
end
