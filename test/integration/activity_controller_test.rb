require "test_helper"

class ActivityControllerTest < ActionDispatch::IntegrationTest
  setup do
    @database = PgPeek::Database.find("primary")
  end

  test "show lists running sessions with their source" do
    conn = open_pg_session
    conn.send_query(sleeping_query(controller: "posts", action: "show"))
    wait_for("the query to start") { sessions.active.any? { |row| row["pid"].to_i == conn.backend_pid } }

    get pg_peek.database_activity_path(@database)

    assert_response :success
    assert_select "h1", text: "activity"
    assert_select "tr[data-filter-value='#{conn.backend_pid}']", text: /active.*posts#show.*pg_sleep/m
    assert_select "article[aria-label='Blocked sessions']", count: 0
  end

  test "show calls out blocked sessions and who blocks them" do
    holder = open_pg_session
    holder.exec("SELECT pg_advisory_lock(424243)")
    waiter = open_pg_session
    waiter.send_query("SELECT pg_advisory_lock(424243)")
    wait_for("the lock wait") { sessions.blocked.any? { |row| row["pid"].to_i == waiter.backend_pid } }

    get pg_peek.database_activity_path(@database)

    assert_response :success
    assert_select "article[aria-label='Blocked sessions'] header", text: /waiting for a lock/
    assert_select "article[aria-label='Blocked sessions'] tr[data-filter-value='#{waiter.backend_pid}']",
                  text: /advisory lock.*#{holder.backend_pid}/m
  end

  test "show hides idle sessions until asked" do
    conn = open_pg_session
    conn.exec("SELECT 1")
    wait_for("the session to go idle") { sessions.idle.any? { |row| row["pid"].to_i == conn.backend_pid } }

    get pg_peek.database_activity_path(@database)
    assert_select "tr[data-filter-value='#{conn.backend_pid}']", count: 0
    assert_select "a", text: "show idle"

    get pg_peek.database_activity_path(@database, idle: 1)
    assert_select "tr[data-filter-value='#{conn.backend_pid}']", text: /idle/
  end

  test "show refreshes only at the offered intervals" do
    get pg_peek.database_activity_path(@database, refresh: 5)
    assert_select "meta[http-equiv=refresh][content='5']"

    get pg_peek.database_activity_path(@database, refresh: 1)
    assert_select "meta[http-equiv=refresh]", count: 0

    get pg_peek.database_activity_path(@database)
    assert_select "meta[http-equiv=refresh]", count: 0
  end

  test "show needs no pg_stat_statements" do
    not_preloaded = PgPeek::PgStatStatements.new(database: @database)
    not_preloaded.define_singleton_method(:preloaded?) { false }

    PgPeek::PgStatStatements.stub(:new, not_preloaded) do
      get pg_peek.database_activity_path(@database)
    end

    assert_response :success
    assert_select "h1", text: "activity"
  end

  private
    def sessions
      PgPeek::Reports::Sessions.new(database: @database)
    end
end
