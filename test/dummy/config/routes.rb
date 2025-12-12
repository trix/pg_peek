Rails.application.routes.draw do
  mount PgPeek::Engine => "/pg_peek"
end
