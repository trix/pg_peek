require_relative "lib/pg_peek/version"

Gem::Specification.new do |spec|
  spec.name        = "pg_peek"
  spec.version     = PgPeek::VERSION
  spec.authors     = [ "Tomasz Mazur" ]
  spec.email       = [ "tomasz.mazur@hey.com" ]
  spec.homepage    = "https://github.com/trix/pg_peek"
  spec.summary     = "PostgreSQL query performance monitoring for Rails applications"
  spec.description = "A Rails Engine that provides a web UI for monitoring and analyzing PostgreSQL query performance. Mount pg_peek into your Rails application to introspect database queries, analyze pg_stat_statements data, track Active Job queries, and parse SQLcommenter tags for performance optimization."
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/trix/pg_peek"
  spec.metadata["changelog_uri"] = "https://github.com/trix/pg_peek/releases"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 7.1.0"
  spec.add_dependency "pg", ">= 1.0"
end
