require "test_helper"
require "minitest/mock"

class PgPeek::PgStatStatementsTest < ActiveSupport::TestCase
  setup do
    @database = PgPeek::Database.find("primary")
    @pg_stat_statements = PgPeek::PgStatStatements.new(database: @database)
  end

  test "shared_preload_libraries reads the setting from the server" do
    assert_kind_of String, @pg_stat_statements.shared_preload_libraries
  end

  test "preloaded? agrees with the setting the server reports" do
    expected = @pg_stat_statements.shared_preload_libraries.include?(PgPeek::PgStatStatements::LIBRARY_NAME)

    assert_equal expected, @pg_stat_statements.preloaded?
  end

  test "preloaded? is false when shared_preload_libraries is empty" do
    @pg_stat_statements.stub(:shared_preload_libraries, "") do
      assert_not @pg_stat_statements.preloaded?
    end
  end

  test "preloaded? is true when listed among several libraries" do
    @pg_stat_statements.stub(:shared_preload_libraries, "pg_cron, pg_stat_statements, auto_explain") do
      assert @pg_stat_statements.preloaded?
    end
  end

  test "preloaded? is false when another library merely has a similar name" do
    @pg_stat_statements.stub(:shared_preload_libraries, "pg_stat_statements_extra") do
      assert_not @pg_stat_statements.preloaded?
    end
  end

  test "preloaded? asks the module itself when the role may not read the setting" do
    skip_unless_usable(@pg_stat_statements)

    become_unprivileged_role(@database)
    connection = @database.connection

    limited = PgPeek::PgStatStatements.new(database: @database)

    assert limited.preloaded?
    assert limited.usable?
    # The failed SHOW must not have aborted the surrounding transaction.
    assert_equal 1, connection.select_value("SELECT 1")
  end

  test "usable? is false when the extension is installed but not preloaded" do
    skip "pg_stat_statements not available on this server" unless @pg_stat_statements.available?

    @pg_stat_statements.stub(:preloaded?, false) do
      assert_not @pg_stat_statements.usable?
    end
  end

  test "outliers returns nil instead of raising when not preloaded" do
    @pg_stat_statements.stub(:preloaded?, false) do
      assert_nil @pg_stat_statements.outliers
    end
  end

  test "jobs returns nil instead of raising when not preloaded" do
    @pg_stat_statements.stub(:preloaded?, false) do
      assert_nil @pg_stat_statements.jobs
    end
  end

  test "outliers_by_job returns nil instead of raising when not preloaded" do
    @pg_stat_statements.stub(:preloaded?, false) do
      assert_nil @pg_stat_statements.outliers_by_job("SomeJob")
    end
  end

  test "reset_at returns nil instead of raising when not preloaded" do
    @pg_stat_statements.stub(:preloaded?, false) do
      assert_nil @pg_stat_statements.reset_at
    end
  end

  test "the statistics leave pg_peek's own queries out" do
    skip_unless_usable(@pg_stat_statements)

    # The outliers query is expensive enough to make its own top list. Running
    # it twice guarantees it has been recorded by the time it is read back.
    @pg_stat_statements.outliers
    rows = PgPeek::PgStatStatements.new(database: @database).outliers

    # Both halves matter. Without the first, a marker that pg_stat_statements
    # stripped would make the second pass trivially while excluding nothing.
    recorded = @database.connection.select_value(
      "SELECT count(*) FROM pg_stat_statements WHERE query LIKE '%/* pg_peek */%'"
    ).to_i
    assert_operator recorded, :>, 0, "expected the marker to survive into pg_stat_statements"

    # Identifiers survive normalisation where string constants do not, so the
    # engine's own statements are recognised by aliases only they use.
    own = rows.select { |row| row["query"].match?(/sync_io_time|max_queries_per_request|total_exec_time_ms/) }
    assert_empty own, own.map { |row| row["query"][0, 60] }
  end

  test "reset_at reads from its own database rather than the primary" do
    analytics = PgPeek::Database.find("analytics")
    skip "analytics database not configured" unless analytics&.connection_configured?

    analytics_stat = PgPeek::PgStatStatements.new(database: analytics)
    skip_unless_usable(analytics_stat)

    # pg_stat_statements_info holds one cluster-wide value, so reading it through
    # the wrong connection returns the same thing on a single server. Removing the
    # extension from the primary makes the wrong connection fail loudly instead.
    # The transactional test rolls the drop back afterwards.
    ActiveRecord::Base.connection.execute("DROP EXTENSION IF EXISTS pg_stat_statements")

    expected = analytics.connection.select_value("SELECT stats_reset FROM pg_stat_statements_info")

    assert_kind_of Time, analytics_stat.reset_at
    assert_in_delta Time.zone.parse(expected.to_s), analytics_stat.reset_at, 1
  end
end
