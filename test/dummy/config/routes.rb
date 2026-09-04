Rails.application.routes.draw do
  mount PgPeek::Engine => "/pg_peek"

  resources :posts, only: [ :index, :show ]

  root to: redirect("/pg_peek")
end
