module PgPeek
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Creates a PgPeek initializer and mounts the engine."

      class_option :skip_routes, type: :boolean, default: false,
        desc: "Don't mount the engine in config/routes.rb"

      def copy_initializer
        template "initializer.rb", "config/initializers/pg_peek.rb"
      end

      def mount_engine
        return if options[:skip_routes]

        if engine_mounted?
          say_status :identical, "config/routes.rb (PgPeek::Engine already mounted)", :blue
          return
        end

        route %(mount PgPeek::Engine, at: "/pg_peek")
      end

      def show_readme
        readme "README" if behavior == :invoke
      end

      private
        # Rails' route action appends unconditionally, so re-running the
        # generator would mount the engine a second time.
        def engine_mounted?
          routes = File.join(destination_root, "config/routes.rb")

          File.exist?(routes) && File.read(routes).include?("PgPeek::Engine")
        end
    end
  end
end
