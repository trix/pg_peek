require "test_helper"

class PgPeek::IndexesTest < ActiveSupport::TestCase
  setup do
    @database = PgPeek::Database.find("primary")
  end

  test "lists every index on user tables with size and scan count" do
    rows = PgPeek::Reports::Indexes.new(database: @database).rows

    assert rows.any?
    assert rows.any? { |row| row["index_name"] == "posts_pkey" }
    rows.each do |row|
      assert row["size"].present?
      assert_match(/\A\d+\z/, row["scans"].to_s)
    end
  end

  test "flags a never-scanned index that enforces nothing as unused" do
    @database.connection.execute("CREATE INDEX index_posts_on_body_for_test ON posts (body)")

    report = PgPeek::Reports::Indexes.new(database: @database)

    assert_includes report.unused.map { |row| row["index_name"] }, "index_posts_on_body_for_test"
    assert_equal "unused", report.rows.first["note"], "unused indexes sort first"
  end

  test "judges an index reset on its own by its own window on PostgreSQL 19" do
    skip "needs PostgreSQL 19 or later" if @database.major_version < 19

    connection = @database.connection
    connection.execute("CREATE INDEX index_posts_on_title_for_test ON posts (title)")
    reset_index_counters("index_posts_on_status", scan: "SELECT count(*) FROM posts WHERE status = 'none'")
    @database.define_singleton_method(:stats_reset_at) { 2.days.ago }

    report = PgPeek::Reports::Indexes.new(database: @database)
    reset = report.rows.find { |row| row["index_name"] == "index_posts_on_status" }
    untouched = report.rows.find { |row| row["index_name"] == "index_posts_on_title_for_test" }
    settled = report.unused_for(1.hour).map { |row| row["index_name"] }

    assert_equal "unused, scans counted since #{Time.now.utc.to_date.iso8601}", reset["note"]
    assert_equal "unused", untouched["note"]
    assert_not_includes settled, "index_posts_on_status"
    assert_includes settled, "index_posts_on_title_for_test"
  end

  test "unused_for leaves every index out while the database's statistics are young" do
    @database.connection.execute("CREATE INDEX index_posts_on_body_for_test ON posts (body)")
    @database.define_singleton_method(:stats_reset_at) { 10.minutes.ago }

    report = PgPeek::Reports::Indexes.new(database: @database)

    assert_includes report.unused.map { |row| row["index_name"] }, "index_posts_on_body_for_test"
    assert_empty report.unused_for(1.hour)
  end

  test "never counts a primary key or unique index as unused" do
    report = PgPeek::Reports::Indexes.new(database: @database)
    pkey = report.rows.find { |row| row["index_name"] == "posts_pkey" }

    assert_equal "primary key", pkey["kind"]
    assert_not_includes report.unused, pkey
  end

  test "leaves indexes on excluded tables out" do
    names = PgPeek::Reports::Indexes.new(database: @database).rows.map { |row| row["table_name"] }

    assert_not_includes names, "schema_migrations"
    assert_not_includes names, "ar_internal_metadata"
  end

  private
    # PostgreSQL only stamps a reset on an index it holds statistics for, and
    # it holds none until the index has been scanned. Both the scan and the
    # reset have to be committed to count, so they go through a session of
    # their own rather than the test's transaction.
    def reset_index_counters(index, scan:)
      session = open_pg_session
      session.exec("SET enable_seqscan = off")
      session.exec(scan)
      session.exec("SELECT pg_stat_force_next_flush()")
      wait_for("#{index} to be scanned") { index_statistic(index, "idx_scan").to_i.positive? }

      session.exec("SELECT pg_stat_reset_single_table_counters('#{index}'::regclass)")
      wait_for("#{index} to be reset") { index_statistic(index, "stats_reset").present? }
    end

    def index_statistic(index, column)
      @database.connection.select_value("SELECT #{column} FROM pg_stat_user_indexes WHERE indexrelname = '#{index}'")
    end
end
