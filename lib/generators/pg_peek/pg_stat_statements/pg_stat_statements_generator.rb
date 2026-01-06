require "rails/generators/active_record"

module PgPeek
  module Generators
    class PgStatStatementsGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      desc "Creates a migration to enable the pg_stat_statements extension."

      class_option :database, type: :string, aliases: %i[--db],
        desc: "The database for your migration. By default, the current environment's primary database is used."

      def create_migration_file
        migration_template "migration.rb.tt", File.join(db_migrate_path, "enable_extension_pg_stat_statements.rb")
      end
    end
  end
end
