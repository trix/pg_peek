require "test_helper"
require "rails/generators/test_case"
require "generators/pg_peek/install/install_generator"

class InstallGeneratorTest < Rails::Generators::TestCase
  tests PgPeek::Generators::InstallGenerator
  destination File.expand_path("../../tmp/generator", __dir__)

  setup :prepare_destination
  setup :write_routes_file

  test "creates the initializer" do
    run_generator

    assert_file "config/initializers/pg_peek.rb", /config\.connections/
  end

  test "mounts the engine in config/routes.rb" do
    run_generator

    assert_file "config/routes.rb", %r{mount PgPeek::Engine, at: "/pg_peek"}
  end

  test "does not mount the engine twice when run again" do
    run_generator
    run_generator

    assert_equal 1, File.read(routes_path).scan("mount PgPeek::Engine").size
  end

  test "leaves routes alone with --skip-routes" do
    run_generator %w[--skip-routes]

    assert_file "config/routes.rb"
    assert_no_match(/PgPeek::Engine/, File.read(routes_path))
  end

  private

  def routes_path
    File.join(destination_root, "config/routes.rb")
  end

  def write_routes_file
    FileUtils.mkdir_p(File.dirname(routes_path))
    File.write(routes_path, "Rails.application.routes.draw do\nend\n")
  end
end
