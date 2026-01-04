require "rails/generators/active_record"

module PgPeek
  module Generators
    class PgStatStatementsGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      desc "Creates a migration to enable the pg_stat_statements extension."

      def create_migration_file
        migration_template "migration.rb.tt", "db/migrate/enable_extension_pg_stat_statements.rb"
      end
    end
  end
end
