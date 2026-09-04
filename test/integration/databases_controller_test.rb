require "test_helper"

class DatabasesControllerTest < ActionDispatch::IntegrationTest
  test "index lists the databases that have a connection configured" do
    get pg_peek.databases_path

    assert_response :success
    assert_select "a[href='#{pg_peek.database_path(PgPeek::Database.find('primary'))}']"
    assert_select "article[aria-label='No database connections configured']", count: 0
  end

  test "index explains how to configure connections when none are set" do
    with_connections({}) do
      get pg_peek.databases_path
    end

    assert_response :success
    assert_select "article[aria-label='No database connections configured']" do
      # Naming what was found separates this from having no PostgreSQL at all.
      assert_select "code", text: "primary"
      assert_select "code", text: /bin\/rails generate pg_peek:install/
    end
  end

  test "index suggests a connections mapping for the databases it found" do
    with_connections({}) do
      get pg_peek.databases_path
    end

    assert_select "article[aria-label='No database connections configured'] pre",
                  text: /"primary" => "ApplicationRecord"/
  end

  private

  def with_connections(connections)
    config = Rails.application.config.pg_peek
    original = config.connections
    config.connections = connections
    yield
  ensure
    config.connections = original
  end
end
