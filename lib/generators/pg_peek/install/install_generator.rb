module PgPeek
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Creates a PgPeek initializer in your application."

      def copy_initializer
        template "initializer.rb", "config/initializers/pg_peek.rb"
      end

      def show_readme
        readme "README" if behavior == :invoke
      end
    end
  end
end
