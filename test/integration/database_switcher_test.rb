require "test_helper"

class DatabaseSwitcherTest < ActionDispatch::IntegrationTest
  setup do
    @primary = PgPeek::Database.find("primary")
    @queue = PgPeek::Database.find("queue")
  end

  test "offers every configured database when there is more than one" do
    get pg_peek.database_path(@primary)

    assert_select "select[data-switcher] option", count: 3
    assert_select "select[data-switcher] option[selected]", text: "primary"
  end

  test "switching keeps you in the same section" do
    get pg_peek.database_endpoints_path(@primary)

    assert_select "select[data-switcher] option[value='#{pg_peek.database_endpoints_path(@queue)}']", text: "queue"
  end

  test "switching from a detail page lands on its section" do
    get pg_peek.database_job_path(@primary, "PostPublishJob")

    assert_select "select[data-switcher] option[value='#{pg_peek.database_jobs_path(@queue)}']", text: "queue"
  end

  test "shows a plain name when only one database is configured" do
    with_connections("primary" => "ApplicationRecord") do
      get pg_peek.database_path(@primary)
    end

    assert_select "select[data-switcher]", count: 0
    assert_select "nav a", text: "primary"
  end

  test "is absent on pages with no database in context" do
    get pg_peek.databases_path

    assert_select "select[data-switcher]", count: 0
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
