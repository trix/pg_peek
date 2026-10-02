Rails.application.routes.draw do
  mount PgPeek::Engine => "/pg_peek"

  resources :posts, only: [ :index, :show ]

  namespace :admin do
    resources :posts, only: [ :index ]
  end

  root to: redirect("/pg_peek")
end
