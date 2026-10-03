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
    assert_select ".vitals a[href='#{pg_peek.database_pg_stat_statements_path(database)}']", text: /stats since/
  end

  test "show names a namespaced job by its class name in the jobs panel" do
    database = PgPeek::Database.find("primary")
    skip_unless_usable(PgPeek::PgStatStatements.new(database: database))
    Reports::PostSummaryJob.perform_now

    get pg_peek.database_path(database)

    assert_select "td", text: "Reports::PostSummaryJob"
  end

  test "show links job and endpoint names to their pages" do
    database = PgPeek::Database.find("primary")
    skip_unless_usable(PgPeek::PgStatStatements.new(database: database))
    Reports::PostSummaryJob.perform_now
    get "/admin/posts"

    get pg_peek.database_path(database)

    assert_select "a[href='/pg_peek/databases/primary/jobs/Reports::PostSummaryJob']", text: "Reports::PostSummaryJob"
    assert_select "a[href='/pg_peek/databases/primary/endpoints/admin/posts/index']", text: "admin/posts#index"
  end

  test "show flags unused indexes in attention" do
    database = PgPeek::Database.find("primary")
    database.connection.execute("CREATE INDEX index_posts_on_body_for_test ON posts (body)")
    database.define_singleton_method(:stats_reset_at) { 2.days.ago }

    # Any real index is at least one page, so a 1-byte floor counts it.
    with_unused_index_min_size(1) do
      PgPeek::Database.stub(:find, database) do
        get pg_peek.database_path(database)
      end
    end

    assert_select "ul.attention li a[href='#{pg_peek.database_indexes_path(database)}']", text: /unused ind/
  end

  test "show leaves unused indexes below the size floor out of attention" do
    database = PgPeek::Database.find("primary")
    database.connection.execute("CREATE INDEX index_posts_on_body_for_test ON posts (body)")
    database.define_singleton_method(:stats_reset_at) { 2.days.ago }
    size = database.connection.select_value("SELECT pg_relation_size('index_posts_on_body_for_test')").to_i

    with_unused_index_min_size(size + 1) do
      PgPeek::Database.stub(:find, database) do
        get pg_peek.database_path(database)
      end
    end

    assert_response :success
    assert_select "ul.attention li a[href='#{pg_peek.database_indexes_path(database)}']", count: 0
  end

  test "show leaves unused indexes out while statistics are young" do
    database = PgPeek::Database.find("primary")
    database.connection.execute("CREATE INDEX index_posts_on_body_for_test ON posts (body)")
    database.define_singleton_method(:stats_reset_at) { 2.hours.ago }

    with_unused_index_min_size(1) do
      PgPeek::Database.stub(:find, database) do
        get pg_peek.database_path(database)
      end
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

  def with_unused_index_min_size(bytes)
    config = Rails.application.config.pg_peek
    original = config.unused_index_min_size
    config.unused_index_min_size = bytes
    yield
  ensure
    config.unused_index_min_size = original
  end

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
