PgPeek::Engine.routes.draw do
  resources :databases, only: [ :index, :show ] do
    resources :queries, only: [ :index ]
    resources :tables, only: [ :show ], param: :name
    resources :endpoints, only: [ :index ]
    resources :indexes, only: [ :index ]
    resource :activity, only: [ :show ], controller: "activity"
    resources :jobs, only: [ :index, :show ], param: :job_class

    resource :pg_stat_statements, only: [] do
      delete :reset
    end
  end

  root to: "databases#home"
end
