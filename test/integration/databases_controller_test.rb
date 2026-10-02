require "test_helper"
require "minitest/mock"

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

  test "root redirects to the primary database overview" do
    get pg_peek.root_path

    assert_redirected_to pg_peek.database_path(PgPeek::Database.find("primary"))
  end

  test "show returns 404 for an unknown database" do
    get pg_peek.database_path("nope")

    assert_response :not_found
  end

  test "show renders the overview panels when statistics are usable" do
    database = PgPeek::Database.find("primary")
    skip_unless_usable(PgPeek::PgStatStatements.new(database: database))

    get pg_peek.database_path(database)

    assert_response :success
    assert_select "h2", text: /endpoints/
    assert_select "h2", text: /slowest queries/
    assert_select "h2", text: "attention"
    assert_select ".vitals a[href='#{pg_peek.database_path(database, anchor: "pg_stat_statements")}']", text: /stats since/
    assert_select "section#pg_stat_statements form[action='#{pg_peek.reset_database_pg_stat_statements_path(database)}']"
    # The dummy keeps all its databases on one server, as a review app would.
    assert_select "section#pg_stat_statements p", text: /also clears queue and analytics/
  end

  test "show flags unused indexes in attention" do
    database = PgPeek::Database.find("primary")
    database.connection.execute("CREATE INDEX index_posts_on_body_for_test ON posts (body)")
    database.define_singleton_method(:stats_reset_at) { 2.days.ago }

    PgPeek::Database.stub(:find, database) do
      get pg_peek.database_path(database)
    end

    assert_select "ul.attention li a[href='#{pg_peek.database_indexes_path(database)}']", text: /unused ind/
  end

  test "show leaves unused indexes out while statistics are young" do
    database = PgPeek::Database.find("primary")
    database.connection.execute("CREATE INDEX index_posts_on_body_for_test ON posts (body)")
    database.define_singleton_method(:stats_reset_at) { 2.hours.ago }

    PgPeek::Database.stub(:find, database) do
      get pg_peek.database_path(database)
    end

    assert_response :success
    assert_select "ul.attention li a[href='#{pg_peek.database_indexes_path(database)}']", count: 0
  end

  test "show marks young statistics in the header instead of the attention list" do
    database = PgPeek::Database.find("primary")
    skip_unless_usable(PgPeek::PgStatStatements.new(database: database))
    new_stats = PgPeek::PgStatStatements.method(:new)
    young_stats = lambda do |**args|
      new_stats.call(**args).tap { |stats| stats.define_singleton_method(:reset_at) { 10.minutes.ago } }
    end

    PgPeek::PgStatStatements.stub(:new, young_stats) do
      get pg_peek.database_path(database)
    end

    assert_response :success
    assert_select ".vitals a.provisional[title='figures may not be representative yet']", text: /stats since 10 minutes ago/
    assert_select "ul.attention li", text: /statistics were reset/, count: 0
  end

  test "show flags a cache hit ratio below the threshold" do
    database = PgPeek::Database.find("primary")
    database.define_singleton_method(:vitals) { { "cache_hit_ratio" => "42.0" } }

    PgPeek::Database.stub(:find, database) do
      get pg_peek.database_path(database)
    end

    assert_response :success
    assert_select "ul.attention li", text: /cache hit ratio 42\.0% \(below 99%\)/
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

  test "show flags blocked sessions and long queries in attention" do
    database = PgPeek::Database.find("primary")
    holder = open_pg_session
    holder.exec("SELECT pg_advisory_lock(424244)")
    waiter = open_pg_session
    waiter.send_query("SELECT pg_advisory_lock(424244)")
    wait_for("the lock wait") do
      PgPeek::Reports::Sessions.new(database: database).blocked.any? { |row| row["pid"].to_i == waiter.backend_pid }
    end

    get pg_peek.database_path(database)

    assert_response :success
    assert_select "ul.attention li a[href='#{pg_peek.database_activity_path(database)}']", text: /waiting for a lock/
    assert_select "section h2", text: /activity/
  end
end
