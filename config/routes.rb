PgPeek::Engine.routes.draw do
  resources :databases, only: [ :index, :show ] do
    resources :queries, only: [ :index ]
    resources :tables, only: [ :index, :show ], param: :name
    resources :endpoints, only: [ :index ]
    # admin/posts#index lives at endpoints/admin/posts/index: the slashes of a
    # namespace stay as they are, and no # needs encoding.
    get "endpoints/*endpoint_controller/:endpoint_action", to: "endpoints#show", as: :endpoint, format: false
    resources :indexes, only: [ :index ]
    resource :activity, only: [ :show ], controller: "activity"
    resources :jobs, only: [ :index, :show ], param: :job_class

    resource :pg_stat_statements, only: [] do
      delete :reset
    end
  end

  root to: "databases#home"
end
