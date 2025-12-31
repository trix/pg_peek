module PgPeek
  class Engine < ::Rails::Engine
    isolate_namespace PgPeek

    config.pg_peek = Configuration.new
  end
end
