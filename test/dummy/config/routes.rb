Rails.application.routes.draw do
  mount PgPeek::Engine => "/pg_peek"

  root to: redirect("/pg_peek")
end
