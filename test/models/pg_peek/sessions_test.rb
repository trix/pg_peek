require "test_helper"

class PgPeek::SessionsTest < ActiveSupport::TestCase
  setup do
    @database = PgPeek::Database.find("primary")
  end

  test "lists another session with its state and how long it has run" do
    conn = open_pg_session
    conn.send_query(sleeping_query)
    wait_for("the query to start") { report.active.any? { |row| row["pid"].to_i == conn.backend_pid } }

    row = report.rows.find { |r| r["pid"].to_i == conn.backend_pid }

    assert_equal "active", row["state"]
    assert_operator row["duration_ms"].to_i, :>=, 0
    assert_match(/pg_sleep/, row["query"])
  end

  test "attributes a session to its endpoint from the query tags" do
    conn = open_pg_session
    conn.send_query(sleeping_query(controller: "posts", action: "index"))
    wait_for("the query to start") { report.active.any? { |row| row["pid"].to_i == conn.backend_pid } }

    row = report.rows.find { |r| r["pid"].to_i == conn.backend_pid }

    assert_equal "posts#index", row["source"]
  end

  test "reports a session waiting on a lock and who holds it" do
    holder = open_pg_session
    holder.exec("SELECT pg_advisory_lock(424242)")
    waiter = open_pg_session
    waiter.send_query("SELECT pg_advisory_lock(424242) /*job='ReportJob'*/")
    wait_for("the lock wait") { report.blocked.any? { |row| row["pid"].to_i == waiter.backend_pid } }

    sessions = report
    row = sessions.blocked.find { |r| r["pid"].to_i == waiter.backend_pid }
    assert_includes row["blocked_by"], holder.backend_pid
    assert_equal "blocked by #{holder.backend_pid}", row["wait"]
    assert_equal row, sessions.rows.first, "blocked sessions sort first"

    blocked = PgPeek::Reports::Blocked.new(database: @database, sessions: sessions).rows
    entry = blocked.find { |r| r["pid"].to_i == waiter.backend_pid }
    assert_equal "advisory lock (exclusive)", entry["waiting_for"]
    assert_equal "ReportJob", entry["source"]
    assert_equal holder.backend_pid.to_s, entry["blocked_by"]
    assert_match(/idle/, entry["blocker"])
    assert_match(/pg_advisory_lock/, entry["blocker_query"])
  end

  test "keeps idle connections out of the busy list but counts them" do
    conn = open_pg_session
    conn.exec("SELECT 1")
    wait_for("the session to go idle") { report.idle.any? { |row| row["pid"].to_i == conn.backend_pid } }

    sessions = report
    assert_includes sessions.idle.map { |row| row["pid"].to_i }, conn.backend_pid
    assert_not_includes sessions.busy.map { |row| row["pid"].to_i }, conn.backend_pid
  end

  test "flags long queries and stale transactions by threshold" do
    running = open_pg_session
    running.send_query(sleeping_query)
    open = open_pg_session
    open.exec("BEGIN")
    open.exec("SELECT 1")
    wait_for("both sessions") do
      pids = report.rows.map { |row| row["pid"].to_i }
      pids.include?(running.backend_pid) && pids.include?(open.backend_pid)
    end

    sessions = report
    assert_includes sessions.long_running(0).map { |row| row["pid"].to_i }, running.backend_pid
    assert_not_includes sessions.long_running(60_000).map { |row| row["pid"].to_i }, running.backend_pid
    assert_includes sessions.stale_transactions(0).map { |row| row["pid"].to_i }, open.backend_pid
    assert_not_includes sessions.stale_transactions(60_000).map { |row| row["pid"].to_i }, open.backend_pid
  end

  test "leaves its own session out" do
    own = @database.connection.select_value("SELECT pg_backend_pid()").to_i

    assert_not_includes report.rows.map { |row| row["pid"].to_i }, own
  end

  private
    # A fresh report each time: rows are memoised, and the point is to look again.
    def report
      PgPeek::Reports::Sessions.new(database: @database)
    end
end
